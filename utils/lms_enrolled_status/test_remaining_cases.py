"""Local tests for the audited repeated cycle; missing audit stays report-only."""
import copy
import unittest
from psycopg.types.json import Jsonb
import test_repair as fixtures
import test_backfill_before_dropout as drop_fixtures
import remaining_cases as remaining


class RemainingTest(unittest.TestCase):
    setUp=fixtures.RepairTest.setUp
    add_student=fixtures.RepairTest.add_student
    audit=fixtures.RepairTest.audit
    drop=drop_fixtures.HistoryTest.drop

    def cycle(self,sid=1):
        uid=sid*10
        rid,first=self.drop(sid)
        self.conn.execute("UPDATE enrollment_record SET is_current=false,end_date='2026-08-03' WHERE id=%s",(rid,))
        undo=self.audit(sid,'student_program_dropout_undo',changes={'status':{'old':'dropout','new':'enrolled'},'batch_id':{'old':None,'new':7}})
        self.conn.execute("""UPDATE lms_student_write_audits SET inserted_at='2026-08-03',updated_at='2026-08-03',
          affected_identifiers=affected_identifiers || %s WHERE id=%s""",(Jsonb({'dropout_audit_id':first}),undo))
        secondrow=self.conn.execute("""INSERT INTO enrollment_record(user_id,group_type,group_id,is_current,
          start_date,academic_year,inserted_at,updated_at) VALUES(%s,'status',3,true,'2026-08-04',
          '2026-2027','2026-08-04','2026-08-04') RETURNING id""",(uid,)).fetchone()['id']
        changes=self.conn.execute('SELECT changed_values FROM lms_student_write_audits WHERE id=%s',(first,)).fetchone()['changed_values']
        changes['dropout_status_enrollment_id']['new']=secondrow
        changes['dropout_date']['new']='2026-08-04'
        changes['batch_enrollment_end_date']['new']='2026-08-04'
        last=self.audit(sid,'student_program_dropout',changes=changes)
        self.conn.execute("UPDATE lms_student_write_audits SET inserted_at='2026-08-04',updated_at='2026-08-04' WHERE id=%s",(last,))
        self.conn.execute("UPDATE enrollment_record SET end_date='2026-08-04' WHERE user_id=%s AND group_type!='status'",(uid,))
        return rid,secondrow,first,undo,last

    def report(self):return remaining.inventory(self.conn)
    def apply(self,manifest):return remaining.apply_manifest(self.conn,manifest,'local-qa@example.invalid')

    def test_adds_two_periods_preserves_both_dropouts_and_reruns(self):
        self.cycle();manifest=self.report()
        before=self.conn.execute('SELECT * FROM enrollment_record ORDER BY id').fetchall()
        students=self.conn.execute('SELECT * FROM student').fetchall()
        audits=self.conn.execute('SELECT * FROM lms_student_write_audits ORDER BY id').fetchall()
        result=self.apply(manifest)
        self.assertEqual(len(result[0]['periods']),2)
        new=self.conn.execute('SELECT * FROM enrollment_record WHERE id>%s ORDER BY id',(before[-1]['id'],)).fetchall()
        self.assertEqual([(str(r['start_date']),str(r['end_date']),r['is_current']) for r in new],[('2026-07-01','2026-08-02',False),('2026-08-03','2026-08-04',False)])
        self.assertEqual(before,self.conn.execute('SELECT * FROM enrollment_record WHERE id<=%s ORDER BY id',(before[-1]['id'],)).fetchall())
        self.assertEqual(students,self.conn.execute('SELECT * FROM student').fetchall())
        self.assertEqual(audits,self.conn.execute('SELECT * FROM lms_student_write_audits WHERE id<=%s ORDER BY id',(audits[-1]['id'],)).fetchall())
        self.assertEqual(self.apply(manifest)[0]['result'],'already_applied')
        self.assertEqual(self.report()['summary']['box_count'],0)

    def test_missing_audit_is_report_only_even_when_db_dates_agree(self):
        _,aid=self.drop();self.conn.execute('DELETE FROM lms_student_write_audits WHERE id=%s',(aid,))
        manifest=self.report()
        self.assertEqual(manifest['rows'],[])
        self.assertEqual(manifest['summary']['manual_review_count'],1)
        self.assertFalse(manifest['manual_review'][0]['automatic_repair'])
        with self.assertRaises(ValueError):self.apply(manifest)

    def test_missing_audit_cannot_be_smuggled_into_approved_rows(self):
        self.cycle();manifest=self.report();self.add_student(2);self.drop(2)
        self.conn.execute("DELETE FROM lms_student_write_audits WHERE affected_identifiers->>'student_pk_id'='2' AND action='student_program_dropout'")
        manifest['rows'][0]['student_id']=2
        manifest['rows'][0]['periods'][0]['proposed']['user_id']=20
        with self.assertRaises(ValueError):self.apply(manifest)
        self.assertEqual(self.conn.execute("SELECT count(*) AS n FROM enrollment_record WHERE group_type='status' AND group_id=2").fetchone()['n'],0)

    def test_bad_undo_link_order_and_identity_are_rejected(self):
        _,_,first,undo,last=self.cycle()
        for key,value in [('dropout_audit_id',last),('user_id',999)]:
            with self.conn.transaction(force_rollback=True):
                self.conn.execute('UPDATE lms_student_write_audits SET affected_identifiers=affected_identifiers || %s WHERE id=%s',(Jsonb({key:value}),undo))
                self.assertEqual(self.report()['rows'],[])
        self.conn.execute("UPDATE lms_student_write_audits SET inserted_at='2026-08-05' WHERE id=%s",(undo,))
        self.assertEqual(self.report()['rows'],[])

    def test_wrong_dropout_state_end_date_and_membership_are_rejected(self):
        firstrow,secondrow,_,_,last=self.cycle()
        for sql,args in [("UPDATE enrollment_record SET end_date='2026-08-05' WHERE id=%s",(firstrow,)),
                         ('UPDATE enrollment_record SET is_current=false WHERE id=%s',(secondrow,)),
                         ('UPDATE lms_student_write_audits SET changed_values=changed_values || %s WHERE id=%s',(Jsonb({'batch_id':{'old':8,'new':None}}),last))]:
            with self.conn.transaction(force_rollback=True):
                self.conn.execute(sql,args);self.assertEqual(self.report()['rows'],[])

    def test_stale_second_student_rolls_back_both_periods(self):
        self.cycle();self.add_student(2);self.cycle(2);manifest=self.report()
        self.conn.execute("UPDATE student SET status='enrolled' WHERE id=2")
        with self.assertRaises(ValueError):
            with self.conn.transaction():self.apply(manifest)
        self.assertEqual(self.conn.execute("SELECT count(*) AS n FROM enrollment_record WHERE group_id=2 AND group_type='status'").fetchone()['n'],0)
        self.assertEqual(self.conn.execute('SELECT count(*) AS n FROM lms_student_write_audits WHERE action=%s',(remaining.ACTION,)).fetchone()['n'],0)

    def test_manifest_and_repaired_period_changes_rejected(self):
        self.cycle();manifest=self.report()
        for key,value in [('database','prod'),('script_sha256','bad'),('academic_year','2025-2026')]:
            modified=copy.deepcopy(manifest);modified[key]=value
            with self.assertRaises(ValueError):self.apply(modified)
        modified=copy.deepcopy(manifest);modified['rows'][0]['periods'][1]['proposed']['is_current']=True
        with self.assertRaises(ValueError):self.apply(modified)
        result=self.apply(manifest)
        self.conn.execute("UPDATE enrollment_record SET end_date='2026-08-05' WHERE id=%s",(result[0]['periods'][1]['enrollment_id'],))
        with self.assertRaisesRegex(ValueError,'Repaired row changed'):self.apply(manifest)


if __name__=='__main__':unittest.main()
