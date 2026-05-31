#!/usr/bin/env python3
"""
One-off chapter.name correction script for the 2026-27 LMS timemap.

The correction data is intentionally checked in as JSON next to this script.
Generated backup files are written before updates and are intentionally ignored
by git.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_DATA_FILE = SCRIPT_DIR / "chapter_name_updates.json"
DEFAULT_BACKUP_DIR = SCRIPT_DIR / "backups"
DEFAULT_DB = {
    "host": "localhost",
    "port": 5432,
    "dbname": "dbservice_dev",
    "user": "postgres",
    "password": "postgres",
}


def load_driver():
    try:
        import psycopg  # type: ignore

        return "psycopg3", psycopg
    except ImportError:
        try:
            import psycopg2  # type: ignore

            return "psycopg2", psycopg2
        except ImportError:
            raise SystemExit(
                "Missing Postgres driver. Install one of:\n"
                "  python -m pip install psycopg[binary]\n"
                "  python -m pip install psycopg2-binary"
            )


def connect(args: argparse.Namespace):
    _driver_name, driver = load_driver()
    database_url = args.database_url or os.environ.get("DATABASE_URL")

    if database_url:
        return driver.connect(database_url)

    return driver.connect(
        host=os.environ.get("PGHOST", DEFAULT_DB["host"]),
        port=int(os.environ.get("PGPORT", DEFAULT_DB["port"])),
        dbname=os.environ.get("PGDATABASE", DEFAULT_DB["dbname"]),
        user=os.environ.get("PGUSER", DEFAULT_DB["user"]),
        password=os.environ.get("PGPASSWORD", DEFAULT_DB["password"]),
    )


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise SystemExit(f"Refusing to overwrite existing backup file: {path}")

    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")


def timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def default_backup_file() -> Path:
    return DEFAULT_BACKUP_DIR / f"chapter_name_backup_{timestamp()}.json"


def load_corrections(path: Path) -> tuple[dict[str, Any], list[dict[str, str]]]:
    payload = read_json(path)
    corrections = payload.get("corrections")
    if not isinstance(corrections, list) or not corrections:
        raise SystemExit(f"No corrections found in {path}")

    seen: set[str] = set()
    for row in corrections:
        for key in ("chapter_code", "expected_current_name", "new_chapter_name"):
            if not isinstance(row.get(key), str) or not row[key].strip():
                raise SystemExit(f"Invalid correction row, missing {key}: {row}")

        code = row["chapter_code"]
        if code in seen:
            raise SystemExit(f"Duplicate chapter_code in correction data: {code}")
        seen.add(code)

    return payload, corrections


def placeholders(items: list[Any]) -> str:
    return ", ".join(["%s"] * len(items))


def fetch_chapters(cursor: Any, codes: list[str]) -> dict[str, dict[str, Any]]:
    cursor.execute(
        f"""
        SELECT
          id,
          code,
          name::text,
          COALESCE(
            (
              SELECT element->>'chapter'
              FROM jsonb_array_elements(name) AS element
              WHERE element->>'lang_code' = 'en'
              LIMIT 1
            ),
            (
              SELECT element->>'chapter'
              FROM jsonb_array_elements(name) AS element
              LIMIT 1
            )
          ) AS english_name
        FROM chapter
        WHERE code IN ({placeholders(codes)})
        ORDER BY code
        """,
        codes,
    )

    rows = cursor.fetchall()
    chapters_by_code: dict[str, dict[str, Any]] = {}
    duplicates: set[str] = set()

    for row in rows:
        chapter_id, code, name_text, english_name = row
        if code in chapters_by_code:
            duplicates.add(code)
            continue

        chapters_by_code[code] = {
            "id": chapter_id,
            "code": code,
            "name": json.loads(name_text),
            "english_name": english_name or "",
        }

    if duplicates:
        raise SystemExit(f"Duplicate chapter.code rows found: {', '.join(sorted(duplicates))}")

    missing = sorted(set(codes) - set(chapters_by_code.keys()))
    if missing:
        raise SystemExit(f"Missing chapter.code rows: {', '.join(missing)}")

    return chapters_by_code


def replace_english_name(name_value: Any, new_name: str) -> Any:
    updated = deepcopy(name_value)

    if isinstance(updated, list):
        for item in updated:
            if isinstance(item, dict) and item.get("lang_code") == "en":
                item["chapter"] = new_name
                return updated

        updated.append({"lang_code": "en", "chapter": new_name})
        return updated

    return [{"lang_code": "en", "chapter": new_name}]


def build_plan(
    corrections: list[dict[str, str]],
    chapters_by_code: dict[str, dict[str, Any]],
    strict_current_name: bool,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    changes: list[dict[str, Any]] = []
    unchanged: list[dict[str, Any]] = []
    errors: list[str] = []

    for correction in corrections:
        code = correction["chapter_code"]
        chapter = chapters_by_code[code]
        current_name = chapter["english_name"]
        expected_current_name = correction["expected_current_name"]
        new_name = correction["new_chapter_name"]

        if current_name == new_name:
            unchanged.append(
                {
                    "chapter_code": code,
                    "chapter_id": chapter["id"],
                    "name": current_name,
                    "reason": "already_updated",
                }
            )
            continue

        if strict_current_name and current_name != expected_current_name:
            errors.append(
                f"{code}: expected current name {expected_current_name!r}, "
                f"found {current_name!r}"
            )
            continue

        changes.append(
            {
                "chapter_code": code,
                "chapter_id": chapter["id"],
                "subject": correction.get("subject"),
                "old_english_name": current_name,
                "expected_current_name": expected_current_name,
                "new_chapter_name": new_name,
                "old_name": chapter["name"],
                "new_name": replace_english_name(chapter["name"], new_name),
            }
        )

    if errors:
        raise SystemExit("Current DB state did not match correction file:\n" + "\n".join(errors))

    return changes, unchanged


def print_plan(changes: list[dict[str, Any]], unchanged: list[dict[str, Any]]) -> None:
    print(f"Planned changes: {len(changes)}")
    print(f"Already up to date: {len(unchanged)}")

    for change in changes:
        print(
            f"- {change['chapter_code']}: "
            f"{change['old_english_name']!r} -> {change['new_chapter_name']!r}"
        )


def backup_payload(
    data_file: Path,
    source_payload: dict[str, Any],
    changes: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "data_file": str(data_file),
        "source_version": source_payload.get("version"),
        "source": source_payload.get("source"),
        "changes": changes,
    }


def apply_changes(cursor: Any, changes: list[dict[str, Any]]) -> None:
    for change in changes:
        cursor.execute(
            """
            UPDATE chapter
            SET name = %s::jsonb,
                updated_at = NOW()
            WHERE id = %s
              AND code = %s
            """,
            [
                json.dumps(change["new_name"]),
                change["chapter_id"],
                change["chapter_code"],
            ],
        )
        if cursor.rowcount != 1:
            raise RuntimeError(f"Expected to update one row for {change['chapter_code']}")


def rollback_changes(cursor: Any, backup: dict[str, Any], strict_current_name: bool) -> None:
    changes = backup.get("changes")
    if not isinstance(changes, list) or not changes:
        raise SystemExit("Backup file has no changes to roll back")

    codes = [change["chapter_code"] for change in changes]
    chapters_by_code = fetch_chapters(cursor, codes)

    errors: list[str] = []
    for change in changes:
        code = change["chapter_code"]
        current_name = chapters_by_code[code]["english_name"]
        new_name = change["new_chapter_name"]
        old_name = change["old_english_name"]

        if strict_current_name and current_name not in (new_name, old_name):
            errors.append(
                f"{code}: expected current name {new_name!r} or {old_name!r}, "
                f"found {current_name!r}"
            )

    if errors:
        raise SystemExit("Current DB state did not match backup file:\n" + "\n".join(errors))

    for change in changes:
        cursor.execute(
            """
            UPDATE chapter
            SET name = %s::jsonb,
                updated_at = NOW()
            WHERE id = %s
              AND code = %s
            """,
            [
                json.dumps(change["old_name"]),
                change["chapter_id"],
                change["chapter_code"],
            ],
        )
        if cursor.rowcount != 1:
            raise RuntimeError(f"Expected to roll back one row for {change['chapter_code']}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fix chapter.name values from the approved 2026-27 LMS timemap."
    )
    parser.add_argument("--data-file", type=Path, default=DEFAULT_DATA_FILE)
    parser.add_argument("--backup-file", type=Path)
    parser.add_argument("--database-url")
    parser.add_argument("--apply", action="store_true", help="Write changes. Default is dry run.")
    parser.add_argument("--rollback", action="store_true", help="Restore chapter names from backup.")
    parser.add_argument(
        "--no-current-name-check",
        action="store_true",
        help="Do not require current DB names to match expected names.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    strict_current_name = not args.no_current_name_check

    if args.rollback and not args.backup_file:
        raise SystemExit("--rollback requires --backup-file")

    conn = connect(args)
    try:
        cursor = conn.cursor()

        if args.rollback:
            backup = read_json(args.backup_file)
            change_count = len(backup.get("changes", []))
            print(f"Rollback changes from backup: {change_count}")
            if not args.apply:
                print("Dry run only. Re-run with --apply to restore old names.")
                return 0

            rollback_changes(cursor, backup, strict_current_name)
            conn.commit()
            print(f"Rolled back {change_count} chapter names.")
            return 0

        source_payload, corrections = load_corrections(args.data_file)
        codes = [correction["chapter_code"] for correction in corrections]
        chapters_by_code = fetch_chapters(cursor, codes)
        changes, unchanged = build_plan(corrections, chapters_by_code, strict_current_name)
        print_plan(changes, unchanged)

        if not args.apply:
            print("Dry run only. Re-run with --apply to update chapter names.")
            return 0

        backup_file = args.backup_file or default_backup_file()
        write_json(backup_file, backup_payload(args.data_file, source_payload, changes))
        print(f"Wrote backup file: {backup_file}")

        apply_changes(cursor, changes)
        conn.commit()
        print(f"Updated {len(changes)} chapter names.")
        return 0
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
