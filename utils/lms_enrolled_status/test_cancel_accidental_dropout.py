"""Guardrails for the separate accidental-dropout correction; LOCAL TEMP tables."""
import copy
import unittest
from unittest.mock import patch
from psycopg.types.json import Jsonb
import repair
import cancel_accidental_dropout as correction
import test_repair as fixtures


class CorrectionTest(unittest.TestCase):
    setUp = fixtures.RepairTest.setUp
    add_student = fixtures.RepairTest.add_student
    audit = fixtures.RepairTest.audit

    def cycle(self, sid=1):
        uid = sid * 10
        batch = self.conn.execute("SELECT id FROM enrollment_record WHERE user_id=%s AND group_type='batch'", (uid,)).fetchone()['id']
        row = self.conn.execute("""INSERT INTO enrollment_record(user_id,group_type,group_id,is_current,start_date,
          end_date,academic_year,inserted_at,updated_at) VALUES(%s,'status',3,false,'2026-08-02','2026-08-03',
          '2026-2027','2026-08-02','2026-08-02') RETURNING id""", (uid,)).fetchone()['id']
        drop = self.audit(sid, 'student_program_dropout', changes={
          'status': {'old': 'enrolled', 'new': 'dropout'}, 'dropout_date': {'old': None, 'new': '2026-08-02'},
          'academic_year': {'old': None, 'new': '2026-2027'}, 'batch_id': {'old': 7, 'new': None},
          'batch_enrollment_id': {'old': batch, 'new': None}, 'dropout_status_enrollment_id': {'old': None, 'new': row}})
        undo = self.audit(sid, 'student_program_dropout_undo', changes={
          'status': {'old': 'dropout', 'new': 'enrolled'}, 'batch_id': {'old': None, 'new': 7}})
        self.conn.execute("UPDATE lms_student_write_audits SET inserted_at='2026-08-02',updated_at='2026-08-02' WHERE id=%s", (drop,))
        self.conn.execute("""UPDATE lms_student_write_audits SET inserted_at='2026-08-03',updated_at='2026-08-03',
          affected_identifiers=affected_identifiers || %s WHERE id=%s""", (Jsonb({'dropout_audit_id': drop}), undo))
        return row, drop, undo

    def report(self):
        return correction.inventory(self.conn, '2026-2027')

    def apply(self, manifest):
        return correction.apply_manifest(self.conn, manifest, 'local-qa@example.invalid')

    def test_continuous_enrollment_preserves_id_creation_memberships_and_audits(self):
        rid, _, _ = self.cycle()
        manifest = self.report()
        self.assertEqual(manifest['summary']['box_count'], 1)
        before = self.conn.execute('SELECT * FROM enrollment_record WHERE id=%s', (rid,)).fetchone()
        audits = self.conn.execute('SELECT * FROM lms_student_write_audits ORDER BY id').fetchall()
        students = self.conn.execute('SELECT * FROM student ORDER BY id').fetchall()
        memberships = self.conn.execute("SELECT * FROM enrollment_record WHERE group_type!='status' ORDER BY id").fetchall()
        self.assertEqual(self.apply(manifest)[0]['result'], 'corrected')
        after = self.conn.execute('SELECT * FROM enrollment_record WHERE id=%s', (rid,)).fetchone()
        self.assertEqual(after['inserted_at'], before['inserted_at'])
        self.assertGreater(after['updated_at'], before['updated_at'])
        self.assertEqual((after['group_id'], after['is_current'], str(after['start_date']), after['end_date']), (2, True, '2026-07-01', None))
        self.assertEqual(students, self.conn.execute('SELECT * FROM student ORDER BY id').fetchall())
        self.assertEqual(memberships, self.conn.execute("SELECT * FROM enrollment_record WHERE group_type!='status' ORDER BY id").fetchall())
        self.assertEqual(audits, self.conn.execute('SELECT * FROM lms_student_write_audits WHERE id<=%s ORDER BY id', (audits[-1]['id'],)).fetchall())
        self.assertEqual(self.apply(manifest)[0]['result'], 'already_applied')
        self.assertEqual(self.report()['summary']['box_count'], 0)
        self.assertEqual(self.conn.execute('SELECT count(*) AS n FROM enrollment_record').fetchone()['n'], 5)

    def test_first_box_and_active_dropout_are_not_touched(self):
        self.assertEqual(self.report()['rows'], [])
        self.cycle()
        self.conn.execute("UPDATE student SET status='dropout'")
        self.assertEqual(self.report()['rows'], [])

    def test_undo_must_reference_exact_drop_and_identity(self):
        _, _, undo = self.cycle()
        for key, value in [('dropout_audit_id', 999), ('user_id', 999)]:
            with self.conn.transaction(force_rollback=True):
                self.conn.execute('UPDATE lms_student_write_audits SET affected_identifiers=affected_identifiers || %s WHERE id=%s', (Jsonb({key: value}), undo))
                self.assertEqual(self.report()['rows'], [])

    def test_row_target_dates_year_state_and_status_definition_must_match(self):
        rid, _, _ = self.cycle()
        # Fixed test SQL only; each independent mismatch must fail closed.
        mutations = ["end_date='2026-08-04'", "start_date='2026-08-01'", "is_current=true",
                     "group_id=2", "academic_year='2025-2026'", "subject_id=1", "inserted_at='2026-08-04'"]
        for mutation in mutations:
            with self.subTest(mutation=mutation), self.conn.transaction(force_rollback=True):
                self.conn.execute('UPDATE enrollment_record SET '+mutation+' WHERE id=%s', (rid,))
                self.assertEqual(self.report()['rows'], [])
        self.conn.execute("INSERT INTO status VALUES(4,'dropout')")
        self.assertEqual(self.report()['rows'], [])

    def test_multiple_cycles_or_status_rows_are_not_automatically_cancelled(self):
        self.cycle(); self.cycle()
        self.assertEqual(self.report()['rows'], [])

    def test_audit_order_transition_and_batch_are_checked(self):
        _, drop, undo = self.cycle()
        for aid, patch_value in [(drop, {'status': {'old': 'enrolled', 'new': 'enrolled'}}),
                                  (undo, {'batch_id': {'old': None, 'new': 999}}),
                                  (drop, {'dropout_status_enrollment_id': {'new': 999}})]:
            with self.conn.transaction(force_rollback=True):
                self.conn.execute('UPDATE lms_student_write_audits SET changed_values=changed_values || %s WHERE id=%s', (Jsonb(patch_value), aid))
                self.assertEqual(self.report()['rows'], [])
        self.conn.execute("UPDATE lms_student_write_audits SET inserted_at='2026-07-30' WHERE id=%s", (undo,))
        self.assertEqual(self.report()['rows'], [])

    def test_stale_second_student_rolls_back_entire_batch(self):
        self.cycle(); self.add_student(2); self.cycle(2)
        manifest = self.report()
        self.conn.execute("UPDATE student SET status='dropout' WHERE id=2")
        with self.assertRaisesRegex(ValueError, 'Evidence changed'):
            with self.conn.transaction():
                self.apply(manifest)
        self.assertEqual(self.conn.execute("SELECT count(*) AS n FROM enrollment_record WHERE group_type='status' AND group_id=3").fetchone()['n'], 2)
        self.assertEqual(self.conn.execute('SELECT count(*) AS n FROM lms_student_write_audits WHERE action=%s', (correction.ACTION,)).fetchone()['n'], 0)

    def test_manifest_tampering_and_changed_repair_are_rejected(self):
        rid, _, _ = self.cycle(); original = self.report()
        for key, value in [('database','prod'), ('script_sha256','bad'), ('academic_year','2025-2026')]:
            manifest = copy.deepcopy(original); manifest[key] = value
            with self.assertRaises(ValueError): self.apply(manifest)
        manifest = copy.deepcopy(original); manifest['rows'][0]['proposed']['start_date'] = '2026-01-01'
        with self.assertRaises(ValueError): self.apply(manifest)
        self.apply(original)
        self.conn.execute("UPDATE enrollment_record SET updated_at='2026-01-01' WHERE id=%s", (rid,))
        with self.assertRaisesRegex(ValueError, 'Corrected row changed'): self.apply(original)

    def test_shared_helper_change_invalidates_manifest_and_remote_names_rejected(self):
        self.cycle(); manifest = self.report()
        manifest['script_sha256'] = repair.SCRIPT_HASH
        with self.assertRaises(ValueError): self.apply(manifest)
        with patch('psycopg.connect') as connect:
            with self.assertRaises(ValueError): repair.connect_local('prod_af_db',5432)
            connect.assert_not_called()


if __name__ == '__main__':
    unittest.main()
