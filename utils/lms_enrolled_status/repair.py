#!/usr/bin/env python3
"""Repair of missing initial enrolled status rows for LMS-created Students (local by default)."""
import argparse
from collections import Counter
from datetime import date, datetime, timezone
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import sys

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

ACTION = "student_status_enrollment_backfill"
VERSION = 1
REMOTE_URL_ENV = "STATUS_REPAIR_DATABASE_URL"
REMOTE_BATCH_LIMIT = 100
SCRIPT_HASH = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()


def canonical(value):
    return json.loads(json.dumps(value, default=str))


def digest(value):
    return hashlib.sha256(json.dumps(canonical(value), sort_keys=True).encode()).hexdigest()


def read_evidence(conn, student_ids=None):
    """Read audits once, then use primary-key/User indexes for bounded Student pages."""
    clause = "" if student_ids is None else "WHERE affected_identifiers->>'student_pk_id' = ANY(%s)"
    params = () if student_ids is None else ([str(i) for i in student_ids],)
    audits = conn.execute("""
        SELECT id, action, inserted_at, updated_at,
          affected_identifiers->>'student_pk_id' AS student_id,
          affected_identifiers->>'user_id' AS user_id,
          created_values->>'status' AS created_status,
          created_values->>'grade_id' AS grade_id,
          created_values->>'batch_pk_id' AS batch_id,
          created_values->>'status_enrollment_id' AS status_enrollment_id,
          created_values->>'source_creation_audit_id' AS source_creation_audit_id,
          changed_values AS changes
        FROM lms_student_write_audits
        """ + clause + " ORDER BY id", params).fetchall()
    by_id = {}
    malformed = 0
    for audit in audits:
        key = audit["student_id"]
        if not key or not key.isdigit() or len(key) > 18 or int(key) <= 0:
            malformed += audit["action"] == "student_bulk_create"
            continue
        by_id.setdefault(int(key), []).append(canonical(audit))
    ids = sorted(k for k, rows in by_id.items() if any(a["action"] == "student_bulk_create" for a in rows))
    statuses = canonical(conn.execute("SELECT id,title FROM status ORDER BY id").fetchall())
    result = []
    for offset in range(0, len(ids), 200):
        chunk = ids[offset:offset + 200]
        students = conn.execute("""
          SELECT id,user_id,status,inserted_at,updated_at FROM student
          WHERE id=ANY(%s) ORDER BY id
        """, (chunk,)).fetchall()
        users = sorted({s["user_id"] for s in students if s["user_id"] is not None})
        enrollments = conn.execute("""
          SELECT id,user_id,group_type,group_id,is_current,start_date,end_date,
                 academic_year,subject_id,inserted_at,updated_at
          FROM enrollment_record WHERE user_id=ANY(%s) ORDER BY id
        """, (users,)).fetchall()
        ownership = {r["user_id"]: r["n"] for r in conn.execute(
            "SELECT user_id,count(*) AS n FROM student WHERE user_id=ANY(%s) GROUP BY user_id", (users,))}
        grouped = {}
        for row in enrollments:
            grouped.setdefault(row["user_id"], []).append(canonical(row))
        found = {s["id"] for s in students}
        for student in students:
            result.append({"student": canonical(student), "audits": by_id[student["id"]],
                           "enrollments": grouped.get(student["user_id"], []),
                           "student_count_for_user": ownership.get(student["user_id"], 0)})
        for missing in set(chunk) - found:
            result.append({"student": {"id": missing}, "audits": by_id[missing],
                           "enrollments": [], "student_count_for_user": 0})
    return result, statuses, malformed


def timestamp(value):
    return datetime.fromisoformat(value.replace("T", " "))


def classify(evidence, statuses, year):
    student, audits, enrollments = (evidence[k] for k in ("student", "audits", "enrollments"))
    creates = [a for a in audits if a["action"] == "student_bulk_create"]
    if "user_id" not in student:
        return "missing_student", None
    if len(creates) != 1:
        return "ambiguous_creation_audit", None
    source = creates[0]
    if evidence["student_count_for_user"] != 1 or not student["user_id"]:
        return "ambiguous_student_user", None
    if any(str(a["user_id"]) != str(student["user_id"]) for a in audits):
        return "audit_identity_mismatch", None
    # School identity deliberately does not gate this status-only repair.
    originals = {}
    for kind, audit_key in (("batch", "batch_id"), ("grade", "grade_id")):
        originals[kind] = [e for e in enrollments if e["group_type"] == kind
                           and str(e["group_id"]) == str(source[audit_key])
                           and e["inserted_at"] and student["inserted_at"] and source["inserted_at"]
                           and timestamp(student["inserted_at"]) <= timestamp(e["inserted_at"])
                           <= timestamp(source["inserted_at"])]
    if any(len(rows) != 1 for rows in originals.values()):
        return "unverified_original_memberships", None
    rows = [values[0] for values in originals.values()]
    years = {r["academic_year"] for r in rows}
    if len(years) != 1 or None in years:
        return "ambiguous_academic_year", None
    if years != {year}:
        return "other_academic_year", None
    # Count the requested box independently of the stricter apply checks below.
    status_rows = [e for e in enrollments if e["group_type"] == "status"]
    if status_rows:
        return "existing_status_history", None
    if student["status"] != "enrolled":
        return "student_not_enrolled", None
    dates = {r["start_date"] for r in rows}
    reason = None
    if len(dates) != 1 or None in dates:
        reason = "ambiguous_start_date"
    elif date.fromisoformat(next(iter(dates))) > datetime.now(timezone.utc).date():
        reason = "future_start_date"
    elif source["created_status"] != "enrolled":
        reason = "creation_not_enrolled"
    elif any(a["action"] in ("student_program_dropout", "student_program_dropout_undo") for a in audits):
        reason = "dropout_or_undo_history"
    elif any(a["action"] not in ("student_bulk_create", "student_update") for a in audits):
        reason = "other_audit_history"
    elif any(a["action"] == "student_update" and "status" in a["changes"] for a in audits):
        reason = "status_edited"
    elif not current_memberships_match(enrollments, audits, source, year):
        reason = "current_membership_evidence_mismatch"
    enrolled = [s for s in statuses if s["title"] == "enrolled"]
    if len(enrolled) != 1:
        reason = "missing_or_duplicate_enrolled_definition"
    if reason:
        return "box_excluded:" + reason, None
    proposed = {"user_id": student["user_id"], "group_type": "status", "group_id": enrolled[0]["id"],
                "is_current": True, "start_date": next(iter(dates)), "end_date": None,
                "academic_year": year, "subject_id": None}
    return "proposed", {"student_id": student["id"], "source_creation_audit_id": source["id"],
                        "proposed": proposed, "evidence": evidence, "evidence_sha256": digest(evidence)}


def current_memberships_match(enrollments, audits, source, year):
    # A normal stream/Grade edit replaces memberships, not the enrolled period.
    batch = source["batch_id"]
    for audit in audits:
        if audit["action"] == "student_update" and "batch_id" in audit["changes"]:
            change = audit["changes"]["batch_id"]
            if not isinstance(change, dict) or str(change.get("old")) != str(batch) or change.get("new") is None:
                return False
            batch = change["new"]
    active = [e for e in enrollments if e["is_current"] and e["end_date"] is None]
    batches = [e for e in active if e["group_type"] == "batch"]
    grades = [e for e in active if e["group_type"] == "grade"]
    return (len(batches) == 1 and str(batches[0]["group_id"]) == str(batch)
            and len(grades) == 1 and batches[0]["academic_year"] == year
            and grades[0]["academic_year"] == year)


def inventory(conn, year, expected, after=0, limit=100):
    evidence, statuses, malformed = read_evidence(conn)
    dispositions = Counter()
    proposals = []
    for item in evidence:
        disposition, proposal = classify(item, statuses, year)
        dispositions[disposition] += 1
        if proposal and proposal["student_id"] > after:
            proposals.append(proposal)
    proposals.sort(key=lambda p: p["student_id"])
    count = dispositions["proposed"] + sum(n for k, n in dispositions.items() if k.startswith("box_excluded:"))
    page = proposals[:limit]
    return {"version": VERSION, "script_sha256": SCRIPT_HASH, "academic_year": year,
            "database": target(conn), "summary": {"lms_created_students": len(evidence),
            "box_count": count, "previous_count": expected, "change_since_previous": count - expected,
            "eligible_count": dispositions["proposed"], "dispositions": dict(dispositions),
            "malformed_creation_audits": malformed}, "after_student_id": after,
            "next_after_student_id": page[-1]["student_id"] if page else None,
            "more_candidates": len(proposals) > limit, "rows": page}


def already_applied(conn, plan, fresh):
    logs = [a for a in fresh["audits"] if a["action"] == ACTION
            and a["source_creation_audit_id"] == str(plan["source_creation_audit_id"])]
    if not logs:
        return False
    if len(logs) != 1:
        raise ValueError("Multiple repair audits; investigate")
    log = logs[0]
    status_rows = [e for e in fresh["enrollments"] if e["group_type"] == "status"]
    if len(status_rows) != 1 or str(status_rows[0]["id"]) != log["status_enrollment_id"]:
        raise ValueError("Repaired status history changed; investigate")
    row = status_rows[0]
    if any(row[k] != v for k, v in plan["proposed"].items()):
        raise ValueError("Repaired row changed; regenerate report")
    before = dict(fresh, audits=[a for a in fresh["audits"] if a["id"] != log["id"]],
                  enrollments=[e for e in fresh["enrollments"] if e["id"] != row["id"]])
    if digest(before) != plan["evidence_sha256"]:
        raise ValueError("Student evidence changed after repair")
    return True


def apply_manifest(conn, manifest, actor):
    if manifest["version"] != VERSION or manifest["script_sha256"] != SCRIPT_HASH:
        raise ValueError("Utility changed; regenerate and review the report")
    if manifest["database"] != target(conn):
        raise ValueError("Manifest belongs to a different database")
    plans = manifest["rows"]
    ids = [p["student_id"] for p in plans]
    if not 1 <= len(ids) <= 500 or len(ids) != len(set(ids)):
        raise ValueError("Apply requires 1..500 distinct Students")
    conn.execute("SELECT id FROM student WHERE id=ANY(%s) ORDER BY id FOR UPDATE", (sorted(ids),)).fetchall()
    users = sorted({p["proposed"]["user_id"] for p in plans})
    conn.execute("SELECT id FROM enrollment_record WHERE user_id=ANY(%s) ORDER BY id FOR UPDATE", (users,)).fetchall()
    evidence, statuses, _ = read_evidence(conn, ids)
    fresh = {e["student"]["id"]: e for e in evidence}
    result = []
    for plan in plans:
        state = fresh.get(plan["student_id"])
        if state is None:
            raise ValueError("Student or creation audit missing")
        if already_applied(conn, plan, state):
            result.append({"student_id": plan["student_id"], "result": "already_applied"})
            continue
        disposition, proposal = classify(state, statuses, manifest["academic_year"])
        if disposition != "proposed" or proposal != plan:
            raise ValueError("Evidence changed; regenerate and review the report")
        p = plan["proposed"]
        now = datetime.now(timezone.utc).replace(tzinfo=None, microsecond=0)
        inserted = conn.execute("""
          INSERT INTO enrollment_record(user_id,group_type,group_id,is_current,start_date,end_date,
            academic_year,subject_id,inserted_at,updated_at)
          VALUES (%s,'status',%s,true,%s,NULL,%s,NULL,%s,%s) RETURNING id
        """, (p["user_id"], p["group_id"], p["start_date"], p["academic_year"], now, now)).fetchone()["id"]
        conn.execute("""
          INSERT INTO lms_student_write_audits(action,actor_email,actor_login_type,actor_role,
            row_counts,affected_identifiers,created_values,changed_values,inserted_at,updated_at)
          VALUES (%s,%s,'maintenance','operator',%s,%s,%s,%s,%s,%s)
        """, (ACTION, actor, Jsonb({"created": 1}), Jsonb({"student_pk_id": plan["student_id"], "user_id": p["user_id"]}),
               Jsonb({"status": "enrolled", "status_enrollment_id": inserted,
                      "source_creation_audit_id": plan["source_creation_audit_id"], "start_date": p["start_date"],
                      "academic_year": p["academic_year"], "repair_version": VERSION}), Jsonb({}), now, now))
        result.append({"student_id": plan["student_id"], "result": "created", "enrollment_id": inserted})
    # Verify inserted rows AND unchanged Student/membership/audit evidence before commit.
    verified, _, _ = read_evidence(conn, ids)
    by_id = {e["student"]["id"]: e for e in verified}
    for plan in plans:
        if not already_applied(conn, plan, by_id[plan["student_id"]]):
            raise ValueError("Post-insert verification failed")
    return result


def connect_local(database, port):
    if not database.startswith("dbservice_status_repair_"):
        raise ValueError("Only dedicated dbservice_status_repair_* local databases are allowed")
    conn = psycopg.connect(host="127.0.0.1", port=port, dbname=database,
                           user="postgres", password=os.environ.get("LOCAL_DB_PASSWORD", "postgres"),
                           row_factory=dict_row, connect_timeout=5,
                           options="-c statement_timeout=30000 -c lock_timeout=2000 -c default_transaction_read_only=on")
    try:
        address = conn.execute("SELECT host(inet_server_addr()) AS address").fetchone()["address"]
        if not address or not ipaddress.ip_address(address).is_loopback:
            raise ValueError("The connected PostgreSQL server is not local")
        conn.rollback()
        return conn
    except Exception:
        conn.close()
        raise


def target(conn):
    """Reports bind host, port and database, so they cannot be applied elsewhere."""
    return f"{conn.info.host}:{conn.info.port}/{conn.info.dbname}"


def add_target_args(parser):
    parser.add_argument("--database", required=True,
                        help="Local database name; with --remote, must match the URL's database")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--remote", action="store_true",
                        help=f"Connect using the {REMOTE_URL_ENV} environment variable")


def check_limit(parser, args):
    maximum = REMOTE_BATCH_LIMIT if args.remote else 500
    if not 1 <= args.limit <= maximum or args.after_student_id < 0:
        parser.error(f"limit must be 1..{maximum}; cursor must be nonnegative")


def connect(args):
    if not args.remote:
        return connect_local(args.database, args.port)
    url = os.environ.get(REMOTE_URL_ENV)
    if not url:
        raise ValueError(f"--remote requires {REMOTE_URL_ENV}")
    conn = psycopg.connect(url, row_factory=dict_row, connect_timeout=10,
                           options="-c statement_timeout=30000 -c lock_timeout=2000 -c default_transaction_read_only=on")
    if conn.info.dbname != args.database:
        conn.close()
        raise ValueError("--database does not match the remote database")
    print(f"Connected to {target(conn)}", file=sys.stderr)
    return conn


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    add_target_args(parser)
    parser.add_argument("--academic-year", default="2026-2027")
    parser.add_argument("--previous-count", type=int, default=36817)
    parser.add_argument("--after-student-id", type=int, default=0)
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--apply", type=Path)
    parser.add_argument("--approve-sha256")
    parser.add_argument("--actor")
    args = parser.parse_args()
    if args.academic_year != "2026-2027":
        parser.error("This utility is scoped to academic year 2026-2027")
    check_limit(parser, args)
    if args.apply and (not args.approve_sha256 or not args.actor):
        parser.error("apply requires an approved file hash and actor")
    if not args.apply and (args.approve_sha256 or args.actor):
        parser.error("approval/actor require --apply")
    with open(args.output, "x", opener=lambda path, flags: os.open(path, flags, 0o600)) as output:
        manifest = None
        if args.apply:
            raw = args.apply.read_bytes()
            if hashlib.sha256(raw).hexdigest() != args.approve_sha256:
                raise ValueError("Manifest hash does not match approval")
            manifest = json.loads(raw)
            if manifest["academic_year"] != args.academic_year:
                raise ValueError("Manifest academic year mismatch")
        with connect(args) as conn:
            conn.execute("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ WRITE" if manifest else
                         "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY")
            conn.execute("SET LOCAL TIME ZONE 'UTC'")
            if manifest:
                result = {"manifest_sha256": args.approve_sha256, "verification": apply_manifest(conn, manifest, args.actor)}
            else:
                result = inventory(conn, args.academic_year, args.previous_count, args.after_student_id, args.limit)
            json.dump(result, output, indent=2, default=str)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
    if manifest:
        print("Repair committed; verification saved")
    else:
        print(json.dumps(result["summary"], sort_keys=True))


if __name__ == "__main__":
    main()
