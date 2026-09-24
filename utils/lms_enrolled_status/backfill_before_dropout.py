#!/usr/bin/env python3
"""Missing enrolled periods before one audited dropout (local by default)."""
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

ACTION = 'student_pre_dropout_enrollment_backfill'
SCRIPT_HASH = hashlib.sha256(Path(__file__).read_bytes() + initial.SCRIPT_HASH.encode()).hexdigest()


def change(audit, key, side):
    item = audit['changes'].get(key)
    return item.get(side) if isinstance(item, dict) else None


def classify(evidence, statuses, year):
    student, audits, enrollments = (evidence[k] for k in ('student', 'audits', 'enrollments'))
    if any(a['action'] == ACTION for a in audits):
        return 'previously_repaired', None
    if student.get('status') != 'dropout':
        return 'not_currently_dropout', None
    drops = [a for a in audits if a['action'] == 'student_program_dropout']
    if len(drops) != 1 or any(a['action'] == 'student_program_dropout_undo' for a in audits):
        return 'not_one_dropout_without_undo', None
    drop = drops[0]
    if change(drop, 'academic_year', 'new') != year:
        return 'other_or_missing_academic_year', None

    def reject(reason):
        return 'box_excluded:' + reason, None

    status_rows = [e for e in enrollments if e['group_type'] == 'status']
    dropout = [s['id'] for s in statuses if s['title'] == 'dropout']
    if len(status_rows) != 1 or len(dropout) != 1:
        return reject('ambiguous_status_history_or_definition')
    row = status_rows[0]
    date = change(drop, 'dropout_date', 'new')
    if (row['id'] != change(drop, 'dropout_status_enrollment_id', 'new') or
        row['group_id'] != dropout[0] or row['is_current'] is not True or row['end_date'] is not None or
        row['start_date'] != date or row['academic_year'] != year or row['subject_id'] is not None):
        return reject('dropout_row_mismatch')
    if (change(drop, 'status', 'old'), change(drop, 'status', 'new')) != ('enrolled', 'dropout'):
        return reject('status_transition_mismatch')
    if str(drop['user_id']) != str(student['user_id']):
        return reject('dropout_identity_mismatch')
    if (change(drop, 'batch_enrollment_is_current', 'old') is not True or
        change(drop, 'batch_enrollment_is_current', 'new') is not False or
        change(drop, 'batch_enrollment_end_date', 'old') is not None or
        change(drop, 'batch_enrollment_end_date', 'new') != date or
        change(drop, 'batch_id', 'new') is not None):
        return reject('batch_transition_mismatch')
    batch_id = change(drop, 'batch_enrollment_id', 'old')
    ended_ids = change(drop, 'ended_enrollment_ids', 'old')
    if not isinstance(ended_ids, list) or not all(type(i) is int for i in ended_ids) or type(batch_id) is not int:
        return reject('missing_ended_membership_evidence')
    ended = set(ended_ids + [batch_id])
    batch = [e for e in enrollments if e['id'] == batch_id and e['group_type'] == 'batch'
             and e['group_id'] == change(drop, 'batch_id', 'old') and e['academic_year'] == year]
    if len(batch) != 1:
        return reject('dropout_batch_mismatch')
    # Reconstruct the audited pre-dropout Batch/Grade state IN MEMORY ONLY to
    # reuse first-box creation/date/ownership checks. Never reactivate DB rows.
    baseline = copy.deepcopy(evidence)
    baseline['student']['status'] = 'enrolled'
    baseline['audits'] = [a for a in baseline['audits'] if a['id'] != drop['id']]
    baseline['enrollments'] = [e for e in baseline['enrollments'] if e['group_type'] != 'status']
    for e in baseline['enrollments']:
        if e['id'] in ended and e['group_type'] in ('batch', 'grade'):
            if e['is_current'] is not False or e['end_date'] != date:
                return reject('ended_membership_mismatch')
            e['is_current'], e['end_date'] = True, None
    disposition, base = initial.classify(baseline, statuses, year)
    if disposition != 'proposed':
        return reject('creation_evidence_' + disposition)
    source = next(a for a in audits if a['id'] == base['source_creation_audit_id'])
    if (not date or not base['proposed']['start_date'] <= date <= datetime.now(timezone.utc).date().isoformat() or
        not source['id'] < drop['id'] or not row['inserted_at'] or
        not initial.timestamp(source['inserted_at']) <= initial.timestamp(row['inserted_at'])
        <= initial.timestamp(drop['inserted_at']) <= datetime.now(timezone.utc).replace(tzinfo=None)):
        return reject('date_or_audit_order_mismatch')
    if any(a['id'] > drop['id'] or initial.timestamp(a['inserted_at']) > initial.timestamp(drop['inserted_at']) for a in baseline['audits']):
        return reject('audit_changes_after_dropout')
    proposed = dict(base['proposed'], is_current=False, end_date=date)
    return 'proposed', {'student_id': student['id'], 'source_creation_audit_id': source['id'],
        'dropout_audit_id': drop['id'], 'dropout_enrollment_id': row['id'], 'proposed': proposed,
        'evidence': evidence, 'evidence_sha256': initial.digest(evidence)}


def inventory(conn, after=0, limit=100):
    evidence, statuses, malformed = initial.read_evidence(conn)
    counts, plans = Counter(), []
    for e in evidence:
        disposition, plan = classify(e, statuses, '2026-2027')
        counts[disposition] += 1
        if plan and plan['student_id'] > after:
            plans.append(plan)
    plans.sort(key=lambda p: p['student_id'])
    box = counts['proposed'] + sum(n for k, n in counts.items() if k.startswith('box_excluded:'))
    page = plans[:limit]
    return {'version': 1, 'script_sha256': SCRIPT_HASH, 'database': initial.target(conn),
        'academic_year': '2026-2027', 'summary': {'box_count': box, 'previous_count': 284,
        'change_since_previous': box - 284, 'eligible_count': counts['proposed'],
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
        metadata.get('dropout_enrollment_id') != plan['dropout_enrollment_id']):
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
        manifest['database'] != initial.target(conn) or manifest['academic_year'] != '2026-2027'):
        raise ValueError('Manifest code/database/year mismatch')
    plans = manifest['rows']; ids = [p['student_id'] for p in plans]
    if not 1 <= len(ids) <= 500 or len(ids) != len(set(ids)):
        raise ValueError('Apply requires 1..500 distinct Students')
    conn.execute('SELECT id FROM student WHERE id=ANY(%s) ORDER BY id FOR UPDATE', (sorted(ids),)).fetchall()
    users = sorted({p['proposed']['user_id'] for p in plans})
    conn.execute('SELECT id FROM enrollment_record WHERE user_id=ANY(%s) ORDER BY id FOR UPDATE', (users,)).fetchall()
    evidence, statuses, _ = initial.read_evidence(conn, ids)
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
                  'start_date':p['start_date'],'end_date':p['end_date'],'academic_year':p['academic_year'],'repair_version':1}),
           Jsonb({}),now,now))
        results.append({'student_id':plan['student_id'],'result':'created','enrollment_id':rid})
    verified, _, _ = initial.read_evidence(conn, ids)
    by_id = {e['student']['id']: e for e in verified}
    for plan in plans:
        if not already_applied(conn, plan, by_id[plan['student_id']]):
            raise ValueError('Post-insert verification failed')
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    initial.add_target_args(parser)
    parser.add_argument('--limit', type=int, default=100)
    parser.add_argument('--after-student-id', type=int, default=0)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--apply', type=Path)
    parser.add_argument('--approve-sha256')
    parser.add_argument('--actor')
    args = parser.parse_args()
    initial.check_limit(parser, args)
    if (args.apply and (not args.approve_sha256 or not args.actor)) or (not args.apply and (args.approve_sha256 or args.actor)):
        parser.error('apply requires an approved hash and actor')
    with open(args.output, 'x', opener=lambda path, flags: os.open(path, flags, 0o600)) as output:
        manifest = None
        if args.apply:
            raw = args.apply.read_bytes()
            if hashlib.sha256(raw).hexdigest() != args.approve_sha256:
                raise ValueError('Manifest hash mismatch')
            manifest = json.loads(raw)
        with initial.connect(args) as conn:
            conn.execute('SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ WRITE' if manifest else
                         'SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
            conn.execute("SET LOCAL TIME ZONE 'UTC'")
            result = {'manifest_sha256':args.approve_sha256,'verification':apply_manifest(conn,manifest,args.actor)} if manifest else inventory(conn,args.after_student_id,args.limit)
            json.dump(result,output,indent=2,default=str)
            output.write('\n'); output.flush(); os.fsync(output.fileno())
    print('Repair committed; verification saved' if manifest else json.dumps(result['summary'],sort_keys=True))


if __name__ == '__main__':
    main()
