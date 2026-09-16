#!/usr/bin/env python3
"""Bounded audit-derived enrollment timestamp review/repair; defaults to read-only."""
import argparse
import hashlib
import json
import os
from pathlib import Path

SQL = Path(__file__).with_name("report.sql").read_text()
SQL_HASH = hashlib.sha256(SQL.encode()).hexdigest()


def canonical(value):
    return json.loads(json.dumps(value, default=str))


def report(conn, cursor, limit, ids=None):
    sql = "\n".join(line for line in SQL.splitlines() if not line.lstrip().startswith("--"))
    if ids is not None:
        sql = sql.replace("r.enrollment_id > $1", "r.enrollment_id = ANY($1)")
        cursor = ids
    sql = sql.replace("$1", "%s").replace("$2", "%s")
    return canonical(conn.execute(sql, (cursor, limit)).fetchall())


def apply_manifest(conn, manifest):
    if manifest.get("sql_sha256") != SQL_HASH:
        raise ValueError("Report SQL changed; regenerate and review the dry-run")
    rows = [r for r in manifest["rows"] if r["disposition"] == "proposed"]
    ids = [r["enrollment_id"] for r in rows]
    if not rows or len(rows) > 500 or len(set(ids)) != len(ids):
        raise ValueError("Approve 1..500 distinct proposed enrollment rows")
    # Same order as application mutations: lock Student before enrollments.
    student_ids = sorted({int(r["student_id"]) for r in rows})
    conn.execute("SELECT id FROM student WHERE id = ANY(%s) ORDER BY id FOR UPDATE", (student_ids,)).fetchall()
    conn.execute("SELECT id FROM enrollment_record WHERE id = ANY(%s) ORDER BY id FOR UPDATE", (ids,)).fetchall()
    fresh = {r["enrollment_id"]: r for r in report(conn, 0, 500, ids=ids)}
    verification = []
    for reviewed in rows:
        current = fresh.get(reviewed["enrollment_id"])
        after = dict(reviewed["before"], updated_at=reviewed["proposed_updated_at"])
        # PostgreSQL JSON uses T; psycopg's timestamp rendering uses a space.
        after["updated_at"] = after["updated_at"].replace(" ", "T")
        already = dict(reviewed, before=after, disposition="preserve_equal_or_later")
        if current == already:
            verification.append({"enrollment_id": reviewed["enrollment_id"], "result": "already_repaired", "after": after})
            continue
        if current != reviewed:
            raise ValueError("Evidence or enrollment changed; regenerate and review the dry-run")
        updated = conn.execute(
            "UPDATE enrollment_record AS e SET updated_at = %s WHERE id = %s AND to_jsonb(e) = %s::jsonb RETURNING to_jsonb(e) AS row",
            (reviewed["proposed_updated_at"], reviewed["enrollment_id"], json.dumps(reviewed["before"])),
        ).fetchone()
        if updated is None or canonical(updated["row"]) != after:
            raise ValueError("Before/after verification failed; entire repair rolled back")
        verification.append({"enrollment_id": reviewed["enrollment_id"], "result": "repaired", "before": reviewed["before"], "after": after})
    return verification


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--after-id", type=int, default=0)
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--apply", type=Path, help="Reviewed dry-run JSON; requires approval hash")
    parser.add_argument("--approve-sha256", help="Explicitly approved manifest file SHA256")
    args = parser.parse_args()
    if not 1 <= args.limit <= 500 or args.after_id < 0:
        parser.error("limit must be 1..500 and after-id nonnegative")
    if args.approve_sha256 and not args.apply:
        parser.error("approval hash requires --apply")
    # Open output exclusively BEFORE connecting; never overwrite evidence.
    with args.output.open("x") as output:
        os.chmod(args.output, 0o600)
        import psycopg
        from psycopg.rows import dict_row
        with psycopg.connect(os.environ["DATABASE_URL"], row_factory=dict_row) as conn:
            conn.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ" if not args.apply else "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
            if not args.apply:
                conn.execute("SET TRANSACTION READ ONLY")
            conn.execute("SET LOCAL statement_timeout = '30s'")
            conn.execute("SET LOCAL lock_timeout = '5s'")
            conn.execute("SET LOCAL TIME ZONE 'UTC'")
            if args.apply:
                raw = args.apply.read_bytes()
                digest = hashlib.sha256(raw).hexdigest()
                if digest != args.approve_sha256:
                    raise ValueError("Explicit approval hash must match reviewed manifest")
                result = {"manifest_sha256": digest, "verification": apply_manifest(conn, json.loads(raw))}
            else:
                rows = report(conn, args.after_id, args.limit)
                result = {"sql_sha256": SQL_HASH, "after_id": args.after_id, "limit": args.limit,
                          "next_after_id": rows[-1]["enrollment_id"] if rows else None, "rows": rows}
            # Write and fsync evidence before committing the transaction.
            json.dump(result, output, indent=2, default=str)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
    print("Repair committed; verification saved" if args.apply else "Read-only dry-run saved")


if __name__ == "__main__":
    main()
