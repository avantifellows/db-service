"""The DB-evidence exception is restricted to the one explicitly approved Student."""
import copy
import unittest
from psycopg.types.json import Jsonb
import test_repair as fixtures
import test_backfill_before_dropout as dropped
import approved_db_exception as exception
import remaining_cases


class ExceptionTest(unittest.TestCase):
    add_student=fixtures.RepairTest.add_student
    audit=fixtures.RepairTest.audit
    drop=dropped.HistoryTest.drop

    def setUp(self):
        fixtures.RepairTest.setUp(self)
        self.drop(date='2026-07-27')
        self.conn.execute('ALTER TABLE student ADD COLUMN student_id text')
        self.conn.execute("UPDATE student SET id=500583,user_id=511050,student_id='20272025066071',inserted_at='2026-07-22',updated_at='2026-07-27'")
        self.conn.execute("UPDATE enrollment_record SET user_id=511050,id=CASE group_type WHEN 'auth_group' THEN 2823094 WHEN 'school' THEN 2823095 WHEN 'batch' THEN 2823096 WHEN 'grade' THEN 2823097 END,start_date='2026-07-22',inserted_at='2026-07-22',updated_at='2026-07-22' WHERE group_type!='status'")
        self.conn.execute("UPDATE enrollment_record SET user_id=511050,id=2947084,inserted_at='2026-07-27',updated_at='2026-07-27' WHERE group_type='status'")
        self.conn.execute("DELETE FROM lms_student_write_audits WHERE action='student_program_dropout'")
        self.conn.execute("""UPDATE lms_student_write_audits SET id=175,inserted_at='2026-07-22',updated_at='2026-07-22',
          affected_identifiers=%s""",(Jsonb({'student_pk_id':500583,'user_id':511050}),))

    def report(self):return exception.inventory(self.conn)
    def apply(self,m):return exception.apply_manifest(self.conn,m,'local-qa@example.invalid')

    def test_insert_only_period_has_truthful_source_and_reruns(self):
        manifest=self.report();self.assertEqual(manifest['summary']['eligible_count'],1)
        before=self.conn.execute('SELECT * FROM enrollment_record ORDER BY id').fetchall()
        students=self.conn.execute('SELECT * FROM student').fetchall()
        result=self.apply(manifest)
        rid=result[0]['enrollment_id']
        self.assertEqual(before,self.conn.execute('SELECT * FROM enrollment_record WHERE id!=%s ORDER BY id',(rid,)).fetchall())
        self.assertEqual(students,self.conn.execute('SELECT * FROM student').fetchall())
        row=self.conn.execute('SELECT * FROM enrollment_record WHERE id=%s',(rid,)).fetchone()
        self.assertEqual((str(row['start_date']),str(row['end_date']),row['is_current']),('2026-07-22','2026-07-27',False))
        log=self.conn.execute('SELECT created_values FROM lms_student_write_audits WHERE action=%s',(exception.ACTION,)).fetchone()['created_values']
        self.assertIsNone(log['dropout_audit_id'])
        self.assertEqual(log['evidence_source'],exception.EVIDENCE_SOURCE)
        self.assertEqual(self.apply(manifest)[0]['result'],'already_applied')
        self.assertEqual(self.report()['summary']['box_count'],0)
        self.assertEqual(remaining_cases.inventory(self.conn)['summary']['manual_review_count'],0)

    def test_any_other_identity_is_rejected(self):
        with self.assertRaises(ValueError):exception.read_evidence(self.conn,[999])
        self.conn.execute("UPDATE student SET student_id='different'")
        self.assertEqual(self.report()['rows'],[])

    def test_new_dropout_audit_for_user_blocks_exception(self):
        self.conn.execute("""INSERT INTO lms_student_write_audits(action,affected_identifiers,created_values,changed_values,
          inserted_at,updated_at) VALUES('student_program_dropout',%s,'{}','{}','2026-07-27','2026-07-27')""",(Jsonb({'student_pk_id':999,'user_id':511050}),))
        self.assertEqual(self.report()['rows'],[])

    def test_changed_dates_or_identity_evidence_fail_closed(self):
        for sql in ["UPDATE enrollment_record SET end_date='2026-07-28' WHERE group_type='grade'",
                    "UPDATE enrollment_record SET start_date='2026-07-28' WHERE group_type='status'",
                    "UPDATE student SET updated_at='2026-07-28'",
                    "UPDATE student SET status='enrolled'"]:
            with self.subTest(sql=sql),self.conn.transaction(force_rollback=True):
                self.conn.execute(sql);self.assertEqual(self.report()['rows'],[])

    def test_stale_evidence_and_manifest_changes_cannot_write(self):
        manifest=self.report()
        altered=copy.deepcopy(manifest);altered['rows'][0]['proposed']['end_date']='2026-07-28'
        with self.assertRaises(ValueError):self.apply(altered)
        self.conn.execute("UPDATE enrollment_record SET updated_at='2026-07-28' WHERE group_type='school'")
        with self.assertRaises(ValueError):
            with self.conn.transaction():self.apply(manifest)
        self.assertEqual(self.conn.execute('SELECT count(*) AS n FROM lms_student_write_audits WHERE action=%s',(exception.ACTION,)).fetchone()['n'],0)


if __name__=='__main__':unittest.main()
