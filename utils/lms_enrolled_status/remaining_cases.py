#!/usr/bin/env python3
"""Local repeated-dropout repair and read-only report of missing-audit cases."""
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
import backfill_before_dropout as single

ACTION = 'student_repeated_dropout_enrollment_backfill'
SCRIPT_HASH = hashlib.sha256(Path(__file__).read_bytes() + single.SCRIPT_HASH.encode()).hexdigest()


def read_evidence(conn, ids=None):
    evidence, statuses, malformed = initial.read_evidence(conn, ids)
    audit_ids = [a['id'] for e in evidence for a in e['audits']]
    links = {r['id']: r['dropout_audit_id'] for r in conn.execute('''
      SELECT id,affected_identifiers->>'dropout_audit_id' AS dropout_audit_id
      FROM lms_student_write_audits WHERE id=ANY(%s)''', (audit_ids,))}
    for e in evidence:
        for a in e['audits']:
            a['dropout_audit_id'] = links[a['id']]
    return evidence, statuses, malformed


def classify(evidence, statuses):
    audits, student, rows = (evidence[k] for k in ('audits','student','enrollments'))
    if student.get('id')==500583 and student.get('user_id')==511050 and any(
        a['action']=='student_approved_db_evidence_enrollment_backfill' for a in audits):
        return 'approved_exception_repaired',None
    if any(a['action']==ACTION for a in audits):
        return 'previously_repaired',None
    if student.get('status')!='dropout':
        return 'other_box',None
    drops=[a for a in audits if a['action']=='student_program_dropout']
    undos=[a for a in audits if a['action']=='student_program_dropout_undo']
    if not drops:
        return 'missing_dropout_audit',None
    if len(drops)!=2 or len(undos)!=1:
        return 'other_box',None
    first,last=drops;undo=undos[0]
    def reject(reason):return 'box_excluded:'+reason,None
    if [a['action'] for a in audits]!=['student_bulk_create','student_program_dropout','student_program_dropout_undo','student_program_dropout']:
        return reject('unexpected_audit_sequence')
    source=audits[0]
    if not (first['id']<undo['id']<last['id'] and undo['dropout_audit_id']==str(first['id'])):
        return reject('undo_link_or_order_mismatch')
    if any(str(a['user_id'])!=str(student['user_id']) for a in audits):
        return reject('identity_mismatch')
    if not initial.timestamp(first['inserted_at'])<=initial.timestamp(undo['inserted_at'])<=initial.timestamp(last['inserted_at']):
        return reject('audit_time_order')
    undo_date=initial.timestamp(undo['inserted_at']).date().isoformat()
    if (single.change(undo,'status','old'),single.change(undo,'status','new'))!=('dropout','enrolled'):
        return reject('undo_status_mismatch')
    if (single.change(undo,'batch_id','old') is not None or
        single.change(undo,'batch_id','new')!=single.change(first,'batch_id','old')):
        return reject('undo_batch_mismatch')
    # This one-case utility requires the same restored memberships on both drops.
    for key in ('batch_id','batch_enrollment_id','ended_enrollment_ids','academic_year'):
        side='new' if key=='academic_year' else 'old'
        if single.change(first,key,side)!=single.change(last,key,side):
            return reject('membership_evidence_changed_between_drops')
    status_rows=[r for r in rows if r['group_type']=='status']
    by_id={r['id']:r for r in status_rows}
    one=by_id.get(single.change(first,'dropout_status_enrollment_id','new'))
    two=by_id.get(single.change(last,'dropout_status_enrollment_id','new'))
    if len(status_rows)!=2 or one is None or two is None or one['id']==two['id']:
        return reject('status_row_identity_mismatch')
    if not two['inserted_at'] or initial.timestamp(two['inserted_at']) < initial.timestamp(undo['inserted_at']):
        return reject('second_dropout_predates_undo')
    if one['is_current'] is not False or one['end_date']!=undo_date:
        return reject('first_dropout_not_closed_by_undo')
    periods=[]
    for index,(drop,status) in enumerate(((first,one),(last,two))):
        projected=copy.deepcopy(evidence)
        projected['audits']=[a for a in projected['audits'] if a['id'] in (source['id'],drop['id'])]
        projected['enrollments']=[r for r in projected['enrollments'] if r['group_type']!='status' or r['id']==status['id']]
        if index==0:
            for r in projected['enrollments']:
                if r['id']==one['id']:
                    r['is_current'],r['end_date']=True,None
                elif r['group_type'] in ('batch','grade'):
                    # Latest-drop validation below checks the actual stored state.
                    if r['end_date']==single.change(last,'dropout_date','new'):
                        r['end_date']=single.change(first,'dropout_date','new')
        disposition,plan=single.classify(projected,statuses,'2026-2027')
        if disposition!='proposed':
            return reject(('first_' if index==0 else 'last_')+disposition)
        proposed=plan['proposed']
        if index==1:
            proposed=dict(proposed,start_date=undo_date)
            if not one['start_date']<=undo_date<=proposed['end_date']:
                return reject('restored_period_dates')
        periods.append({'kind':'initial' if index==0 else 'after_undo','proposed':proposed})
    return 'proposed',{'student_id':student['id'],'source_creation_audit_id':source['id'],
        'dropout_audit_ids':[first['id'],last['id']],'undo_audit_id':undo['id'],
        'dropout_enrollment_ids':[one['id'],two['id']],'periods':periods,
        'evidence':evidence,'evidence_sha256':initial.digest(evidence)}


def inventory(conn,after=0,limit=100):
    evidence,statuses,malformed=read_evidence(conn)
    counts,plans,manual=Counter(),[],[]
    for e in evidence:
        disposition,plan=classify(e,statuses);counts[disposition]+=1
        if plan and plan['student_id']>after:plans.append(plan)
        if disposition=='missing_dropout_audit':
            # Report evidence only. Never synthesize a dropout event or auto-apply.
            manual.append({'student_id':e['student']['id'],'automatic_repair':False,
                'reason':'Missing dropout audit; policy/evidence review required','evidence':e})
    plans.sort(key=lambda p:p['student_id']);page=plans[:limit]
    box=counts['proposed']+sum(n for k,n in counts.items() if k.startswith('box_excluded:'))
    return {'version':1,'script_sha256':SCRIPT_HASH,'database':conn.info.dbname,'academic_year':'2026-2027',
        'summary':{'box_count':box,'previous_count':1,'change_since_previous':box-1,
                   'eligible_count':counts['proposed'],'manual_review_count':len(manual),
                   'dispositions':dict(counts),'malformed_creation_audits':malformed},
        'rows':page,'manual_review':manual,'next_after_student_id':page[-1]['student_id'] if page else None,
        'more_candidates':len(plans)>limit}


def already_applied(conn,plan,fresh):
    logs=[a for a in fresh['audits'] if a['action']==ACTION]
    if not logs:return False
    if len(logs)!=1:raise ValueError('Multiple repair audits')
    log=logs[0]
    data=conn.execute('SELECT created_values FROM lms_student_write_audits WHERE id=%s',(log['id'],)).fetchone()['created_values']
    for key in ('source_creation_audit_id','dropout_audit_ids','undo_audit_id','dropout_enrollment_ids'):
        if data.get(key)!=plan[key]:raise ValueError('Repair audit links changed')
    added=data.get('periods',[])
    if len(added)!=2 or len({a['enrollment_id'] for a in added})!=2:raise ValueError('Repair audit periods invalid')
    ids=[]
    for proposed,logged in zip(plan['periods'],added):
        if logged['kind']!=proposed['kind']:raise ValueError('Period order changed')
        matches=[r for r in fresh['enrollments'] if r['id']==logged['enrollment_id']]
        if len(matches)!=1:raise ValueError('Repaired row missing')
        row=matches[0]
        if (any(row[k]!=v for k,v in proposed['proposed'].items()) or
            row['inserted_at']!=log['inserted_at'] or row['updated_at']!=log['inserted_at']):
            raise ValueError('Repaired row changed')
        ids.append(row['id'])
    before=dict(fresh,audits=[a for a in fresh['audits'] if a['id']!=log['id']],
                enrollments=[r for r in fresh['enrollments'] if r['id'] not in ids])
    if initial.digest(before)!=plan['evidence_sha256']:raise ValueError('Other Student evidence changed')
    return True


def apply_manifest(conn,manifest,actor):
    if (manifest['version']!=1 or manifest['script_sha256']!=SCRIPT_HASH or
        manifest['database']!=conn.info.dbname or manifest['academic_year']!='2026-2027'):
        raise ValueError('Manifest code/database/year mismatch')
    plans=manifest['rows'];ids=[p['student_id'] for p in plans]
    if not 1<=len(ids)<=500 or len(ids)!=len(set(ids)):raise ValueError('Apply requires 1..500 distinct Students')
    conn.execute('SELECT id FROM student WHERE id=ANY(%s) ORDER BY id FOR UPDATE',(sorted(ids),)).fetchall()
    users=sorted({p['periods'][0]['proposed']['user_id'] for p in plans})
    conn.execute('SELECT id FROM enrollment_record WHERE user_id=ANY(%s) ORDER BY id FOR UPDATE',(users,)).fetchall()
    evidence,statuses,_=read_evidence(conn,ids);fresh={e['student']['id']:e for e in evidence};results=[]
    for plan in plans:
        state=fresh.get(plan['student_id'])
        if state is None:raise ValueError('Student or creation audit missing')
        if already_applied(conn,plan,state):
            results.append({'student_id':plan['student_id'],'result':'already_applied'});continue
        disposition,proposed=classify(state,statuses)
        if disposition!='proposed' or proposed!=plan:raise ValueError('Evidence changed; regenerate report')
        now=datetime.now(timezone.utc).replace(tzinfo=None,microsecond=0);added=[]
        for period in plan['periods']:
            p=period['proposed']
            rid=conn.execute('''INSERT INTO enrollment_record(user_id,group_type,group_id,is_current,start_date,
              end_date,academic_year,subject_id,inserted_at,updated_at)
              VALUES(%s,'status',%s,false,%s,%s,%s,NULL,%s,%s) RETURNING id''',
              (p['user_id'],p['group_id'],p['start_date'],p['end_date'],p['academic_year'],now,now)).fetchone()['id']
            added.append({'kind':period['kind'],'enrollment_id':rid})
        metadata={k:plan[k] for k in ('source_creation_audit_id','dropout_audit_ids','undo_audit_id','dropout_enrollment_ids')}
        metadata.update(periods=added,repair_version=1)
        conn.execute('''INSERT INTO lms_student_write_audits(action,actor_email,actor_login_type,actor_role,
          row_counts,affected_identifiers,created_values,changed_values,inserted_at,updated_at)
          VALUES(%s,%s,'maintenance','operator',%s,%s,%s,%s,%s,%s)''',
          (ACTION,actor,Jsonb({'created':2}),Jsonb({'student_pk_id':plan['student_id'],'user_id':p['user_id']}),
           Jsonb(metadata),Jsonb({}),now,now))
        results.append({'student_id':plan['student_id'],'result':'created','periods':added})
    verified,_,_=read_evidence(conn,ids);by_id={e['student']['id']:e for e in verified}
    for plan in plans:
        if not already_applied(conn,plan,by_id[plan['student_id']]):raise ValueError('Post-insert verification failed')
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
