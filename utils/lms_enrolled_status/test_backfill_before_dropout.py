"""Local TEMP-table coverage for missing historical enrolled periods."""
import copy
import unittest
from psycopg.types.json import Jsonb
import test_repair as fixtures
import backfill_before_dropout as history


class HistoryTest(unittest.TestCase):
    setUp = fixtures.RepairTest.setUp
    add_student = fixtures.RepairTest.add_student
    audit = fixtures.RepairTest.audit

    def drop(self, sid=1, date='2026-08-02'):
        uid = sid*10
        records = self.conn.execute('SELECT id,group_type FROM enrollment_record WHERE user_id=%s ORDER BY id',(uid,)).fetchall()
        batch = next(r['id'] for r in records if r['group_type']=='batch')
        ended = [r['id'] for r in records if r['id']!=batch]
        self.conn.execute("UPDATE student SET status='dropout',updated_at='2026-08-02' WHERE id=%s",(sid,))
        self.conn.execute('UPDATE enrollment_record SET is_current=false,end_date=%s WHERE user_id=%s',(date,uid))
        rid = self.conn.execute("""INSERT INTO enrollment_record(user_id,group_type,group_id,is_current,start_date,
          academic_year,inserted_at,updated_at) VALUES(%s,'status',3,true,%s,'2026-2027','2026-08-02','2026-08-02') RETURNING id""",(uid,date)).fetchone()['id']
        aid = self.audit(sid,'student_program_dropout',changes={
          'status':{'old':'enrolled','new':'dropout'},'batch_id':{'old':7,'new':None},
          'dropout_date':{'old':None,'new':date},'academic_year':{'old':None,'new':'2026-2027'},
          'batch_enrollment_id':{'old':batch,'new':None},'ended_enrollment_ids':{'old':ended,'new':[]},
          'batch_enrollment_is_current':{'old':True,'new':False},'batch_enrollment_end_date':{'old':None,'new':date},
          'dropout_status_enrollment_id':{'old':None,'new':rid}})
        self.conn.execute("UPDATE lms_student_write_audits SET inserted_at='2026-08-02',updated_at='2026-08-02' WHERE id=%s",(aid,))
        return rid,aid

    def report(self):
        return history.inventory(self.conn)

    def apply(self, manifest):
        return history.apply_manifest(self.conn,manifest,'local-qa@example.invalid')

    def test_preserves_current_dropout_and_every_existing_record(self):
        rid,_ = self.drop();manifest=self.report()
        self.assertEqual(manifest['summary']['box_count'],1)
        records=self.conn.execute('SELECT * FROM enrollment_record ORDER BY id').fetchall()
        students=self.conn.execute('SELECT * FROM student ORDER BY id').fetchall()
        audits=self.conn.execute('SELECT * FROM lms_student_write_audits ORDER BY id').fetchall()
        result=self.apply(manifest)
        new=self.conn.execute('SELECT * FROM enrollment_record WHERE id=%s',(result[0]['enrollment_id'],)).fetchone()
        self.assertEqual((new['group_id'],new['is_current'],str(new['start_date']),str(new['end_date'])),(2,False,'2026-07-01','2026-08-02'))
        self.assertEqual(records,self.conn.execute('SELECT * FROM enrollment_record WHERE id<=%s ORDER BY id',(rid,)).fetchall())
        self.assertEqual(students,self.conn.execute('SELECT * FROM student ORDER BY id').fetchall())
        self.assertEqual(audits,self.conn.execute('SELECT * FROM lms_student_write_audits WHERE id<=%s ORDER BY id',(audits[-1]['id'],)).fetchall())
        self.assertEqual(self.apply(manifest)[0]['result'],'already_applied')
        self.assertEqual(self.report()['summary']['box_count'],0)

    def test_other_boxes_do_not_qualify(self):
        self.assertEqual(self.report()['rows'],[])
        self.drop(); self.audit(1,'student_program_dropout_undo')
        self.assertEqual(self.report()['rows'],[])
        self.conn.execute("DELETE FROM lms_student_write_audits WHERE action LIKE 'student_program_dropout%'")
        self.assertEqual(self.report()['rows'],[])

    def test_repeated_dropout_and_existing_enrolled_period_are_excluded(self):
        self.drop(); self.drop()
        self.assertEqual(self.report()['rows'],[])
        self.conn.execute('DELETE FROM lms_student_write_audits WHERE id=(SELECT max(id) FROM lms_student_write_audits)')
        self.assertEqual(self.report()['rows'],[])

    def test_date_identity_membership_and_status_mismatches_fail_closed(self):
        rid,aid=self.drop()
        mutations=[('UPDATE enrollment_record SET is_current=false WHERE id=%s',(rid,)),
                   ("UPDATE enrollment_record SET start_date='2026-08-03' WHERE id=%s",(rid,)),
                   ("UPDATE enrollment_record SET inserted_at='2026-08-03' WHERE id=%s",(rid,)),
                   ("UPDATE enrollment_record SET is_current=true WHERE group_type='grade'",()),
                   ("UPDATE enrollment_record SET end_date='2026-08-01' WHERE group_type='batch'",()),
                   ('UPDATE lms_student_write_audits SET affected_identifiers=affected_identifiers || %s WHERE id=%s',(Jsonb({'user_id':999}),aid)),
                   ('UPDATE lms_student_write_audits SET changed_values=changed_values || %s WHERE id=%s',(Jsonb({'status':{'old':'dropout','new':'dropout'}}),aid))]
        for sql,args in mutations:
            with self.subTest(sql=sql),self.conn.transaction(force_rollback=True):
                self.conn.execute(sql,args);self.assertEqual(self.report()['rows'],[])

    def test_same_day_period_uses_same_boundary_as_dropout(self):
        self.drop(date='2026-07-01');manifest=self.report()
        self.assertEqual(manifest['rows'][0]['proposed']['start_date'],manifest['rows'][0]['proposed']['end_date'])
        self.assertEqual(self.apply(manifest)[0]['result'],'created')

    def test_inverted_period_and_duplicate_status_definition_are_excluded(self):
        self.drop(date='2026-06-30');self.assertEqual(self.report()['rows'],[])
        self.conn.execute("UPDATE enrollment_record SET start_date='2026-06-01' WHERE group_type IN ('batch','grade')")
        self.assertEqual(len(self.report()['rows']),1)
        self.conn.execute("INSERT INTO status VALUES(4,'enrolled')")
        self.assertEqual(self.report()['rows'],[])

    def test_stale_batch_rolls_back_both_new_row_and_audit(self):
        self.drop();self.add_student(2);self.drop(2);manifest=self.report()
        self.conn.execute("UPDATE student SET status='enrolled' WHERE id=2")
        with self.assertRaisesRegex(ValueError,'Evidence changed'):
            with self.conn.transaction():self.apply(manifest)
        self.assertEqual(self.conn.execute("SELECT count(*) AS n FROM enrollment_record WHERE group_type='status' AND group_id=2").fetchone()['n'],0)
        self.assertEqual(self.conn.execute('SELECT count(*) AS n FROM lms_student_write_audits WHERE action=%s',(history.ACTION,)).fetchone()['n'],0)

    def test_manifest_changes_and_changed_current_dropout_are_rejected(self):
        rid,_=self.drop();original=self.report()
        for key,value in [('database','prod'),('script_sha256','bad'),('academic_year','2025-2026')]:
            manifest=copy.deepcopy(original);manifest[key]=value
            with self.assertRaises(ValueError):self.apply(manifest)
        altered=copy.deepcopy(original);altered['rows'][0]['proposed']['is_current']=True
        with self.assertRaises(ValueError):self.apply(altered)
        self.apply(original)
        self.conn.execute("UPDATE enrollment_record SET updated_at='2026-08-03' WHERE id=%s",(rid,))
        with self.assertRaisesRegex(ValueError,'Other Student evidence changed'):self.apply(original)

    def test_audit_link_or_new_row_tampering_is_rejected_on_rerun(self):
        self.drop();manifest=self.report();result=self.apply(manifest)
        with self.conn.transaction(force_rollback=True):
            self.conn.execute('UPDATE lms_student_write_audits SET created_values=created_values || %s WHERE action=%s',(Jsonb({'dropout_audit_id':999}),history.ACTION))
            with self.assertRaisesRegex(ValueError,'Repair audit links changed'):self.apply(manifest)
        self.conn.execute("UPDATE enrollment_record SET is_current=true WHERE id=%s",(result[0]['enrollment_id'],))
        with self.assertRaisesRegex(ValueError,'Repaired enrollment changed'):self.apply(manifest)


if __name__=='__main__':unittest.main()
