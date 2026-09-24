#!/usr/bin/env python3
"""Correction of the 243 confirmed accidental dropout/undo cases (local by default)."""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path

from psycopg.types.json import Jsonb
import repair as initial

ACTION = 'student_accidental_dropout_correction'
CONFIRMED_FILE = Path(__file__).with_name('confirmed_accidental_dropouts.txt')
# Only Students the cohort owner confirmed; any other dropout/undo is reported, never corrected.
CONFIRMED_STUDENT_IDS = frozenset(int(line) for line in CONFIRMED_FILE.read_text().splitlines()
                                  if line.strip() and not line.startswith('#'))
SCRIPT_HASH = hashlib.sha256(Path(__file__).read_bytes() + CONFIRMED_FILE.read_bytes()
                             + initial.SCRIPT_HASH.encode()).hexdigest()


def read_evidence(conn, ids=None):
    evidence, statuses, malformed = initial.read_evidence(conn, ids)
    audit_ids = [a['id'] for e in evidence for a in e['audits']]
    extra = {r['id']: initial.canonical(r) for r in conn.execute('''
      SELECT id, affected_identifiers->>'dropout_audit_id' AS dropout_audit_id,
        CASE WHEN action=%s THEN created_values ELSE NULL END AS repair_values
      FROM lms_student_write_audits WHERE id=ANY(%s)
    ''', (ACTION, audit_ids))}
    for e in evidence:
        for a in e['audits']:
            a['dropout_audit_id'] = extra[a['id']]['dropout_audit_id']
            # Only maintenance payloads are needed, not creation-audit personal data.
            if a['action'] == ACTION:
                a['repair_values'] = extra[a['id']]['repair_values']
    return evidence, statuses, malformed


def change(audit, key, side):
    item = audit['changes'].get(key)
    return item.get(side) if isinstance(item, dict) else None


def classify(evidence, statuses, year):
    audits, student = evidence['audits'], evidence['student']
    if any(a['action'] == ACTION for a in audits):
        return 'previously_corrected', None
    if student.get('status') != 'enrolled':
        return 'not_currently_enrolled', None
    drops = [a for a in audits if a['action'] == 'student_program_dropout']
    undos = [a for a in audits if a['action'] == 'student_program_dropout_undo']
    if not undos:
        return 'no_undo_history', None
    rows = [e for e in evidence['enrollments'] if e['group_type'] == 'status']
    if rows and all(e['academic_year'] != year for e in rows):
        return 'other_academic_year', None

    def reject(reason):
        return 'box_excluded:' + reason, None

    if len(drops) != 1 or len(undos) != 1 or len(rows) != 1:
        return reject('ambiguous_cycle_or_status_rows')
    drop, undo, row = drops[0], undos[0], rows[0]
    # Reuse first-box ownership, creation/year/date and current membership checks.
    baseline = copy.deepcopy(evidence)
    baseline['audits'] = [a for a in baseline['audits'] if a['action'] not in
                          ('student_program_dropout', 'student_program_dropout_undo')]
    baseline['enrollments'] = [e for e in baseline['enrollments'] if e['group_type'] != 'status']
    disposition, base = initial.classify(baseline, statuses, year)
    if disposition != 'proposed':
        return reject('creation_evidence_' + disposition)
    source = next(a for a in audits if a['id'] == base['source_creation_audit_id'])
    if any(str(a['user_id']) != str(student['user_id']) for a in (drop, undo)):
        return reject('cycle_identity_mismatch')
    if undo['dropout_audit_id'] != str(drop['id']):
        return reject('undo_link_mismatch')
    if not (source['id'] < drop['id'] < undo['id'] and
            initial.timestamp(source['inserted_at']) <= initial.timestamp(drop['inserted_at'])
            <= initial.timestamp(undo['inserted_at']) <= datetime.now(timezone.utc).replace(tzinfo=None)):
        return reject('audit_order')
    if (change(drop, 'status', 'old'), change(drop, 'status', 'new'),
        change(undo, 'status', 'old'), change(undo, 'status', 'new')) != ('enrolled', 'dropout', 'dropout', 'enrolled'):
        return reject('status_transition_mismatch')
    dropout = [s['id'] for s in statuses if s['title'] == 'dropout']
    if len(dropout) != 1 or row['group_id'] != dropout[0] or row['is_current'] is not False:
        return reject('not_one_ended_dropout')
    if (row['id'] != change(drop, 'dropout_status_enrollment_id', 'new') or
        row['academic_year'] != year or change(drop, 'academic_year', 'new') != year or
        row['subject_id'] is not None or row['start_date'] != change(drop, 'dropout_date', 'new') or
        row['end_date'] != initial.timestamp(undo['inserted_at']).date().isoformat()):
        return reject('dropout_row_evidence_mismatch')
    if (not row['start_date'] or not row['inserted_at'] or
        not base['proposed']['start_date'] <= row['start_date'] <= row['end_date'] or
        not initial.timestamp(source['inserted_at']) <= initial.timestamp(row['inserted_at'])
        <= initial.timestamp(drop['inserted_at'])):
        return reject('dropout_dates_mismatch')
    batch = change(drop, 'batch_id', 'old')
    if (batch is None or change(undo, 'batch_id', 'new') != batch or
        change(drop, 'batch_id', 'new') is not None or change(undo, 'batch_id', 'old') is not None or
        not any(e['id'] == change(drop, 'batch_enrollment_id', 'old') and e['group_type'] == 'batch'
                and e['group_id'] == batch and e['academic_year'] == year for e in evidence['enrollments'])):
        return reject('cycle_batch_mismatch')
    if student['id'] not in CONFIRMED_STUDENT_IDS:
        return reject('not_confirmed_accidental')
    return 'proposed', {'student_id': student['id'], 'source_creation_audit_id': source['id'],
        'dropout_audit_id': drop['id'], 'undo_audit_id': undo['id'], 'enrollment_id': row['id'],
        'before': row, 'proposed': base['proposed'], 'evidence': evidence,
        'evidence_sha256': initial.digest(evidence)}


def inventory(conn, year, after=0, limit=100):
    from collections import Counter
    evidence, statuses, malformed = read_evidence(conn)
    counts, plans = Counter(), []
    for item in evidence:
        disposition, plan = classify(item, statuses, year)
        counts[disposition] += 1
        if plan and plan['student_id'] > after:
            plans.append(plan)
    plans.sort(key=lambda p: p['student_id'])
    box = counts['proposed'] + sum(n for k, n in counts.items() if k.startswith('box_excluded:'))
    page = plans[:limit]
    return {'version': 1, 'script_sha256': SCRIPT_HASH, 'database': initial.target(conn),
        'academic_year': year, 'summary': {'box_count': box, 'previous_count': len(CONFIRMED_STUDENT_IDS),
        'change_since_previous': box - len(CONFIRMED_STUDENT_IDS), 'eligible_count': counts['proposed'],
        'dispositions': dict(counts), 'malformed_creation_audits': malformed},
        'next_after_student_id': page[-1]['student_id'] if page else None,
        'more_candidates': len(plans) > limit, 'rows': page}


def already_applied(plan, fresh):
    logs = [a for a in fresh['audits'] if a['action'] == ACTION]
    if not logs:
        return False
    if len(logs) != 1:
        raise ValueError('Multiple correction audits')
    log = logs[0]
    expected = {'source_creation_audit_id': plan['source_creation_audit_id'],
        'dropout_audit_id': plan['dropout_audit_id'], 'undo_audit_id': plan['undo_audit_id'],
        'status_enrollment_id': plan['enrollment_id'], 'repair_version': 1}
    if log['repair_values'] != expected or log['changes'].get('status_enrollment', {}).get('old') != plan['before']:
        raise ValueError('Correction audit changed')
    rows = [e for e in fresh['enrollments'] if e['group_type'] == 'status']
    if len(rows) != 1 or rows[0]['id'] != plan['enrollment_id']:
        raise ValueError('Corrected status history changed')
    row = rows[0]
    after = dict(plan['before'], **plan['proposed'], updated_at=log['inserted_at'])
    if row != after or log['changes']['status_enrollment'].get('new') != after:
        raise ValueError('Corrected row changed')
    original = copy.deepcopy(fresh)
    original['audits'] = [a for a in original['audits'] if a['id'] != log['id']]
    original['enrollments'] = [plan['before'] if e['id'] == row['id'] else e for e in original['enrollments']]
    if initial.digest(original) != plan['evidence_sha256']:
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
    evidence, statuses, _ = read_evidence(conn, ids)
    fresh = {e['student']['id']: e for e in evidence}
    results = []
    for plan in plans:
        state = fresh.get(plan['student_id'])
        if state is None:
            raise ValueError('Student or creation audit missing')
        if already_applied(plan, state):
            results.append({'student_id': plan['student_id'], 'result': 'already_applied'})
            continue
        disposition, proposal = classify(state, statuses, manifest['academic_year'])
        if disposition != 'proposed' or proposal != plan:
            raise ValueError('Evidence changed; regenerate report')
        now = datetime.now(timezone.utc).replace(tzinfo=None, microsecond=0)
        p = plan['proposed']
        row = conn.execute('''UPDATE enrollment_record SET group_id=%s,is_current=true,
            start_date=%s,end_date=NULL,updated_at=%s WHERE id=%s RETURNING *''',
            (p['group_id'], p['start_date'], now, plan['enrollment_id'])).fetchone()
        after = initial.canonical({key: row[key] for key in plan['before']})
        conn.execute('''INSERT INTO lms_student_write_audits(action,actor_email,actor_login_type,actor_role,
            row_counts,affected_identifiers,created_values,changed_values,inserted_at,updated_at)
            VALUES(%s,%s,'maintenance','operator',%s,%s,%s,%s,%s,%s)''',
            (ACTION, actor, Jsonb({'updated': 1}), Jsonb({'student_pk_id': plan['student_id'], 'user_id': p['user_id']}),
             Jsonb({'source_creation_audit_id': plan['source_creation_audit_id'], 'dropout_audit_id': plan['dropout_audit_id'],
                'undo_audit_id': plan['undo_audit_id'], 'status_enrollment_id': plan['enrollment_id'], 'repair_version': 1}),
             Jsonb({'status_enrollment': {'old': plan['before'], 'new': after}}), now, now))
        results.append({'student_id': plan['student_id'], 'result': 'corrected', 'enrollment_id': row['id']})
    verified, _, _ = read_evidence(conn, ids)
    by_id = {e['student']['id']: e for e in verified}
    for plan in plans:
        if not already_applied(plan, by_id[plan['student_id']]):
            raise ValueError('Post-update verification failed')
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
            result = {'manifest_sha256': args.approve_sha256, 'verification': apply_manifest(conn, manifest, args.actor)} if manifest else inventory(conn, '2026-2027', args.after_student_id, args.limit)
            json.dump(result, output, indent=2, default=str)
            output.write('\n'); output.flush(); os.fsync(output.fileno())
    print('Correction committed; verification saved' if manifest else json.dumps(result['summary'], sort_keys=True))


if __name__ == '__main__':
    main()
