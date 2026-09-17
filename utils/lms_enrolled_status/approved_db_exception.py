#!/usr/bin/env python3
"""Local-only approved DB-evidence exception for Student 20272025066071."""
import argparse
from collections import Counter
import copy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
from psycopg.types.json import Jsonb
import repair as initial

ACTION = 'student_approved_db_evidence_enrollment_backfill'
SCRIPT_HASH = hashlib.sha256(Path(__file__).read_bytes() + initial.SCRIPT_HASH.encode()).hexdigest()


STUDENT_ID = 500583
USER_ID = 511050
EXTERNAL_ID = '20272025066071'
EVIDENCE_SOURCE = 'creation_audit_and_corroborating_db_dates_user_approved_exception'
APPROVAL_REFERENCE = 'discord:1550057659800101004; user subsequently approved this one Student'


def read_evidence(conn, ids=None):
    if ids is not None and ids != [STUDENT_ID]:
        raise ValueError('Only the explicitly approved Student is allowed')
    evidence,statuses,malformed=initial.read_evidence(conn,[STUDENT_ID])
    identity=conn.execute('SELECT student_id FROM student WHERE id=%s',(STUDENT_ID,)).fetchone()
    matching=conn.execute('''SELECT id,action,inserted_at FROM lms_student_write_audits
      WHERE action IN ('student_program_dropout','student_program_dropout_undo') AND
      (affected_identifiers->>'student_pk_id'=%s OR affected_identifiers->>'user_id'=%s
       OR affected_identifiers->>'student_id'=%s) ORDER BY id''',
      (str(STUDENT_ID),str(USER_ID),EXTERNAL_ID)).fetchall()
    for e in evidence:
        e['external_student_id']=identity['student_id'] if identity else None
        e['matching_dropout_audits']=initial.canonical(matching)
    return evidence,statuses,malformed


def classify(evidence,statuses,year):
    student,audits,rows=(evidence[k] for k in ('student','audits','enrollments'))
    if any(a['action']==ACTION for a in audits):return 'previously_repaired',None
    def reject(reason):return 'box_excluded:'+reason,None
    if (student.get('id')!=STUDENT_ID or student.get('user_id')!=USER_ID or
        evidence.get('external_student_id')!=EXTERNAL_ID):return reject('unapproved_identity')
    if evidence.get('matching_dropout_audits'):return reject('dropout_audit_now_available')
    if len(audits)!=1 or audits[0]['id']!=175 or audits[0]['action']!='student_bulk_create':
        return reject('creation_or_other_history_changed')
    if student['status']!='dropout':return reject('student_no_longer_dropout')
    source=audits[0]
    dropdefs=[s['id'] for s in statuses if s['title']=='dropout']
    status_rows=[r for r in rows if r['group_type']=='status']
    if len(dropdefs)!=1 or len(status_rows)!=1:return reject('ambiguous_status')
    row=status_rows[0]
    if (row['id']!=2947084 or row['group_id']!=dropdefs[0] or row['is_current'] is not True or
        row['end_date'] is not None or row['start_date']!='2026-07-27' or
        row['academic_year']!=year or row['subject_id'] is not None or
        row['inserted_at']!=student['updated_at'] or
        initial.timestamp(row['inserted_at']).date().isoformat()!='2026-07-27'):
        return reject('dropout_db_evidence_changed')
    baseline=copy.deepcopy(evidence)
    baseline['student']['status']='enrolled'
    baseline['enrollments']=[r for r in baseline['enrollments'] if r['group_type']!='status']
    memberships={r['id']:r for r in baseline['enrollments']}
    for rid,kind in ((2823096,'batch'),(2823097,'grade')):
        r=memberships.get(rid)
        if (not r or r['group_type']!=kind or r['is_current'] is not False or
            r['start_date']!='2026-07-22' or r['end_date']!='2026-07-27' or r['academic_year']!=year):
            return reject('original_membership_dates_changed')
        r['is_current'],r['end_date']=True,None
    disposition,base=initial.classify(baseline,statuses,year)
    if disposition!='proposed':return reject('creation_evidence_'+disposition)
    if base['proposed']['start_date']!='2026-07-22':return reject('start_date_changed')
    proposed=dict(base['proposed'],is_current=False,end_date='2026-07-27')
    return 'proposed',{'student_id':STUDENT_ID,'source_creation_audit_id':175,
        'dropout_audit_id':None,'dropout_enrollment_id':2947084,'proposed':proposed,
        'evidence_source':EVIDENCE_SOURCE,'approval_reference':APPROVAL_REFERENCE,
        'evidence':evidence,'evidence_sha256':initial.digest(evidence)}


def inventory(conn, after=0, limit=100):
    evidence, statuses, malformed = read_evidence(conn)
    counts, plans = Counter(), []
    for e in evidence:
        disposition, plan = classify(e, statuses, '2026-2027')
        counts[disposition] += 1
        if plan and plan['student_id'] > after:
            plans.append(plan)
    plans.sort(key=lambda p: p['student_id'])
    box = counts['proposed'] + sum(n for k, n in counts.items() if k.startswith('box_excluded:'))
    page = plans[:limit]
    return {'version': 1, 'script_sha256': SCRIPT_HASH, 'database': conn.info.dbname,
        'academic_year': '2026-2027', 'summary': {'box_count': box, 'previous_count': 1,
        'change_since_previous': box - 1, 'eligible_count': counts['proposed'],
        'dispositions': dict(counts), 'malformed_creation_audits': malformed},
        'next_after_student_id': page[-1]['student_id'] if page else None,
        'more_candidates': len(plans) > limit, 'rows': page}


def already_applied(conn, plan, fresh):
    logs = [a for a in fresh['audits'] if a['action'] == ACTION]
    if not logs:
        return False
    if len(logs) != 1:
        raise ValueError('Multiple repair audits')
    log = logs[0]
    metadata = conn.execute('SELECT created_values FROM lms_student_write_audits WHERE id=%s', (log['id'],)).fetchone()['created_values']
    if (metadata.get('source_creation_audit_id') != plan['source_creation_audit_id'] or
        metadata.get('dropout_audit_id') != plan['dropout_audit_id'] or
        metadata.get('dropout_enrollment_id') != plan['dropout_enrollment_id'] or
        metadata.get('evidence_source') != EVIDENCE_SOURCE or metadata.get('approval_reference') != APPROVAL_REFERENCE):
        raise ValueError('Repair audit links changed')
    rows = [e for e in fresh['enrollments'] if str(e['id']) == log['status_enrollment_id']]
    if len(rows) != 1:
        raise ValueError('Repaired enrollment missing')
    row = rows[0]
    if (any(row[k] != v for k, v in plan['proposed'].items()) or
        row['inserted_at'] != log['inserted_at'] or row['updated_at'] != log['inserted_at']):
        raise ValueError('Repaired enrollment changed')
    before = dict(fresh, audits=[a for a in fresh['audits'] if a['id'] != log['id']],
                  enrollments=[e for e in fresh['enrollments'] if e['id'] != row['id']])
    if initial.digest(before) != plan['evidence_sha256']:
        raise ValueError('Other Student evidence changed')
    return True


def apply_manifest(conn, manifest, actor):
    if (manifest['version'] != 1 or manifest['script_sha256'] != SCRIPT_HASH or
        manifest['database'] != conn.info.dbname or manifest['academic_year'] != '2026-2027'):
        raise ValueError('Manifest code/database/year mismatch')
    plans = manifest['rows']; ids = [p['student_id'] for p in plans]
    if not 1 <= len(ids) <= 500 or len(ids) != len(set(ids)):
        raise ValueError('Apply requires 1..500 distinct Students')
    conn.execute('SELECT id FROM student WHERE id=ANY(%s) ORDER BY id FOR UPDATE', (sorted(ids),)).fetchall()
    users = sorted({p['proposed']['user_id'] for p in plans})
    conn.execute('SELECT id FROM enrollment_record WHERE user_id=ANY(%s) ORDER BY id FOR UPDATE', (users,)).fetchall()
    evidence, statuses, _ = read_evidence(conn, ids)
    fresh = {e['student']['id']: e for e in evidence}
    results = []
    for plan in plans:
        state = fresh.get(plan['student_id'])
        if state is None:
            raise ValueError('Student or creation audit missing')
        if already_applied(conn, plan, state):
            results.append({'student_id': plan['student_id'], 'result': 'already_applied'})
            continue
        disposition, proposal = classify(state, statuses, manifest['academic_year'])
        if disposition != 'proposed' or proposal != plan:
            raise ValueError('Evidence changed; regenerate report')
        now = datetime.now(timezone.utc).replace(tzinfo=None, microsecond=0)
        p = plan['proposed']
        rid = conn.execute('''INSERT INTO enrollment_record(user_id,group_type,group_id,is_current,
          start_date,end_date,academic_year,subject_id,inserted_at,updated_at)
          VALUES(%s,'status',%s,false,%s,%s,%s,NULL,%s,%s) RETURNING id''',
          (p['user_id'],p['group_id'],p['start_date'],p['end_date'],p['academic_year'],now,now)).fetchone()['id']
        conn.execute('''INSERT INTO lms_student_write_audits(action,actor_email,actor_login_type,actor_role,
          row_counts,affected_identifiers,created_values,changed_values,inserted_at,updated_at)
          VALUES(%s,%s,'maintenance','operator',%s,%s,%s,%s,%s,%s)''',
          (ACTION,actor,Jsonb({'created':1}),Jsonb({'student_pk_id':plan['student_id'],'user_id':p['user_id']}),
           Jsonb({'status':'enrolled','status_enrollment_id':rid,'source_creation_audit_id':plan['source_creation_audit_id'],
                  'dropout_audit_id':plan['dropout_audit_id'],'dropout_enrollment_id':plan['dropout_enrollment_id'],
                  'start_date':p['start_date'],'end_date':p['end_date'],'academic_year':p['academic_year'],'repair_version':1,
                  'evidence_source':EVIDENCE_SOURCE,'approval_reference':APPROVAL_REFERENCE}),
           Jsonb({}),now,now))
        results.append({'student_id':plan['student_id'],'result':'created','enrollment_id':rid})
    verified, _, _ = read_evidence(conn, ids)
    by_id = {e['student']['id']: e for e in verified}
    for plan in plans:
        if not already_applied(conn, plan, by_id[plan['student_id']]):
            raise ValueError('Post-insert verification failed')
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database', required=True)
    parser.add_argument('--port', type=int, default=5432)
    parser.add_argument('--limit', type=int, default=100)
    parser.add_argument('--after-student-id', type=int, default=0)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--apply', type=Path)
    parser.add_argument('--approve-sha256')
    parser.add_argument('--actor')
    args = parser.parse_args()
    if not 1 <= args.limit <= 500 or args.after_student_id < 0:
        parser.error('limit must be 1..500; cursor nonnegative')
    if (args.apply and (not args.approve_sha256 or not args.actor)) or (not args.apply and (args.approve_sha256 or args.actor)):
        parser.error('apply requires an approved hash and actor')
    with open(args.output, 'x', opener=lambda path, flags: os.open(path, flags, 0o600)) as output:
        manifest = None
        if args.apply:
            raw = args.apply.read_bytes()
            if hashlib.sha256(raw).hexdigest() != args.approve_sha256:
                raise ValueError('Manifest hash mismatch')
            manifest = json.loads(raw)
        with initial.connect_local(args.database, args.port) as conn:
            conn.execute('SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ WRITE' if manifest else
                         'SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
            conn.execute("SET LOCAL TIME ZONE 'UTC'")
            result = {'manifest_sha256':args.approve_sha256,'verification':apply_manifest(conn,manifest,args.actor)} if manifest else inventory(conn,args.after_student_id,args.limit)
            json.dump(result,output,indent=2,default=str)
            output.write('\n'); output.flush(); os.fsync(output.fileno())
    print('Local repair committed; verification saved' if manifest else json.dumps(result['summary'],sort_keys=True))


if __name__ == '__main__':
    main()
