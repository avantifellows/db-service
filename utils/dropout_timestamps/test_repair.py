"""Integration regressions on a dedicated LOCAL database, using temporary tables."""
import copy
import unittest
from datetime import datetime

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

import repair


class RepairTest(unittest.TestCase):
    def setUp(self):
        # Intentionally does not read DATABASE_URL: tests can never target production.
        self.conn = psycopg.connect(
            host="localhost", dbname="dbservice_test_issue730", user="postgres",
            password="postgres", row_factory=dict_row,
        )
        self.addCleanup(self.conn.close)
        self.conn.execute("CREATE TEMP TABLE student (id bigint, user_id bigint)")
        self.conn.execute("CREATE TEMP TABLE status (id bigint, title text)")
        self.conn.execute("""CREATE TEMP TABLE enrollment_record (
            id bigint, user_id bigint, group_id bigint, group_type text,
            is_current boolean, end_date date, inserted_at timestamp, updated_at timestamp)
        """)
        self.conn.execute("""CREATE TEMP TABLE lms_student_write_audits (
            id bigint, action text, inserted_at timestamp,
            affected_identifiers jsonb, changed_values jsonb)
        """)
        self.conn.execute("INSERT INTO student VALUES (1, 10)")
        self.conn.execute("INSERT INTO status VALUES (8, 'dropout')")
        self.enrollment(101, "batch", 7)
        self.enrollment(102, "school", 9)
        self.enrollment(103, "status", 8, current=False, end_date="2026-09-04")
        self.dropout(1, 2)
        self.undo(2, 3, 1)
        self.dropout(3, 3)
        self.undo(4, 4, 3)

    def enrollment(self, id, kind, group, current=True, end_date=None):
        self.conn.execute("INSERT INTO enrollment_record VALUES (%s, 10, %s, %s, %s, %s, '2026-09-01', '2026-09-01')",
                          (id, group, kind, current, end_date))

    def dropout(self, id, day):
        self.audit(id, day, "student_program_dropout", {
            "batch_enrollment_id": {"old": 101}, "batch_id": {"old": 7},
            "ended_enrollment_ids": {"old": [102]},
            "dropout_status_enrollment_id": {"new": 103},
            "dropout_date": {"new": f"2026-09-{day:02}"},
        })

    def undo(self, id, day, dropout_id, user_id=10):
        self.audit(id, day, "student_program_dropout_undo", {},
                   {"student_pk_id": 1, "user_id": user_id, "dropout_audit_id": dropout_id})

    def audit(self, id, day, action, changes, identifiers=None):
        self.conn.execute("INSERT INTO lms_student_write_audits VALUES (%s,%s,%s,%s,%s)",
                          (id, action, datetime(2026, 9, day),
                           Jsonb(identifiers or {"student_pk_id": 1, "user_id": 10}), Jsonb(changes)))

    def manifest(self):
        return {"sql_sha256": repair.SQL_HASH, "rows": repair.report(self.conn, 0, 500)}

    def test_repeated_cycles_rank_latest_before_pagination(self):
        rows = repair.report(self.conn, 101, 1)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["enrollment_id"], 102)
        self.assertEqual(rows[0]["evidence_audit_id"], 4)
        self.assertEqual(rows[0]["event_count"], 4)
        self.assertEqual(rows[0]["disposition"], "proposed")

    def test_latest_dropout_repairs_ended_rows_and_ignores_unaudited_rows(self):
        self.dropout(5, 5)
        self.conn.execute("UPDATE enrollment_record SET is_current=false, end_date='2026-09-05' WHERE id IN (101,102)")
        self.enrollment(104, "batch", 11, current=False, end_date="2026-09-05")
        rows = self.manifest()["rows"]
        self.assertEqual(len(rows), 3)
        for row in rows[:2]:
            self.assertEqual(row["evidence_audit_id"], 5)
            self.assertEqual(row["disposition"], "proposed")
        self.assertEqual(rows[2]["evidence_audit_id"], 4)

    def test_apply_preserves_every_other_column_and_is_repeatable(self):
        manifest = self.manifest()
        result = repair.apply_manifest(self.conn, manifest)
        self.assertEqual(len(result), 3)
        self.assertTrue(all(r["result"] == "repaired" for r in result))
        for item in result:
            before = dict(item["before"])
            after = dict(item["after"])
            self.assertNotEqual(before.pop("updated_at"), after.pop("updated_at"))
            self.assertEqual(before, after)
        repeated = repair.apply_manifest(self.conn, manifest)
        self.assertTrue(all(r["result"] == "already_repaired" for r in repeated))

    def test_later_update_preserved_and_inconsistent_state_unresolved(self):
        self.conn.execute("UPDATE enrollment_record SET updated_at = '2026-09-09' WHERE id=102")
        self.conn.execute("UPDATE enrollment_record SET is_current=false, end_date='2026-09-05' WHERE id=101")
        rows = self.manifest()["rows"]
        self.assertEqual([r["disposition"] for r in rows],
                         ["unresolved_state", "preserve_equal_or_later", "proposed"])

    def test_missing_identity_in_earlier_undo_fails_closed(self):
        self.conn.execute("UPDATE lms_student_write_audits SET affected_identifiers=affected_identifiers-'user_id' WHERE id=2")
        self.assertTrue(all(r["disposition"] == "unresolved_audit_link" for r in self.manifest()["rows"]))

    def test_new_evidence_invalidates_review(self):
        manifest = self.manifest()
        self.dropout(5, 5)
        with self.assertRaisesRegex(ValueError, "Evidence or enrollment changed"):
            repair.apply_manifest(self.conn, manifest)

    def test_changed_snapshot_invalidates_review(self):
        manifest = self.manifest()
        self.conn.execute("UPDATE enrollment_record SET group_id=100 WHERE id=102")
        with self.assertRaisesRegex(ValueError, "Evidence or enrollment changed"):
            with self.conn.transaction():
                repair.apply_manifest(self.conn, manifest)
        self.assertEqual(self.conn.execute("SELECT updated_at FROM enrollment_record WHERE id=101").fetchone()["updated_at"], datetime(2026, 9, 1))

    def test_missing_row_and_wrong_user_unresolved(self):
        self.conn.execute("DELETE FROM enrollment_record WHERE id=101")
        self.conn.execute("UPDATE enrollment_record SET user_id=11 WHERE id=102")
        self.assertEqual([r["disposition"] for r in self.manifest()["rows"]][:2],
                         ["unresolved_missing_enrollment", "unresolved_identity"])

    def test_empty_and_oversized_manifests_rejected(self):
        manifest = self.manifest()
        with self.assertRaisesRegex(ValueError, "1..500"):
            repair.apply_manifest(self.conn, dict(manifest, rows=[]))
        oversized = [dict(manifest["rows"][0], enrollment_id=i) for i in range(501)]
        with self.assertRaisesRegex(ValueError, "1..500"):
            repair.apply_manifest(self.conn, dict(manifest, rows=oversized))

    def test_duplicate_target_in_earlier_cycle_remains_unresolved(self):
        self.conn.execute("UPDATE lms_student_write_audits SET changed_values=jsonb_set(changed_values, '{ended_enrollment_ids,old}', '[102,102]') WHERE id=1")
        self.assertEqual(self.manifest()["rows"][1]["disposition"], "unresolved_audit_link")

    def test_post_review_later_update_rolls_back_all_changes(self):
        manifest = self.manifest()
        self.conn.execute("UPDATE enrollment_record SET updated_at='2026-09-09' WHERE id=102")
        with self.assertRaisesRegex(ValueError, "Evidence or enrollment changed"):
            with self.conn.transaction():
                repair.apply_manifest(self.conn, manifest)
        self.assertEqual(self.conn.execute("SELECT updated_at FROM enrollment_record WHERE id=101").fetchone()["updated_at"], datetime(2026, 9, 1))
        self.assertEqual(self.conn.execute("SELECT updated_at FROM enrollment_record WHERE id=102").fetchone()["updated_at"], datetime(2026, 9, 9))

    def test_malformed_global_target_is_reported_and_blocks_older_repairs(self):
        self.conn.execute("UPDATE lms_student_write_audits SET changed_values=jsonb_set(changed_values, '{ended_enrollment_ids,old}', '[102, \"bad\"]') WHERE id=3")
        coverage = self.conn.execute(repair.Path(__file__).with_name("coverage.sql").read_text()).fetchall()
        self.assertEqual([r["audit_id"] for r in coverage], [3])
        self.assertTrue(all(r["disposition"] == "unresolved_incomplete_audit_history" for r in self.manifest()["rows"]))

    def test_manifest_query_hash_and_duplicate_ids_rejected(self):
        manifest = self.manifest()
        changed = copy.deepcopy(manifest)
        changed["sql_sha256"] = "unreviewed"
        with self.assertRaisesRegex(ValueError, "SQL changed"):
            repair.apply_manifest(self.conn, changed)
        manifest["rows"].append(manifest["rows"][0])
        with self.assertRaisesRegex(ValueError, "distinct"):
            repair.apply_manifest(self.conn, manifest)


if __name__ == "__main__":
    unittest.main()
