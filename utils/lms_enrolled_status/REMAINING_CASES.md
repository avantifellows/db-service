# Remaining repeated-cycle and missing-audit cases — local only

`remaining_cases.py` proposes a repair for the one fully audited repeated cycle
and reports the missing-audit case separately. It **cannot apply** a missing-audit
repair. It inherits the dedicated local database guard and makes no production
connections.

## Repeated dropout → undo → dropout

Require exactly creation → dropout → linked undo → dropout, with matching
Student/User identity, chronological timestamps, two matching dropout rows,
and the same restored Batch/Grade memberships on both dropouts. The utility
reuses the single-dropout validator to verify both sides of the history without
changing any stored membership.

Add two historical, non-current enrolled periods:

1. Original enrollment date → first dropout date.
2. Undo date → second dropout date.

Both existing dropout rows remain unchanged. The current dropout stays current,
and Student.status stays dropout. These events were not included in the user's
152-case accidental-dropout cancellation decision, so neither dropout is erased.
Add one repair audit with both new enrollment IDs and all source audit links.

For the actual snapshot Student, original enrollment was July 25, 2026. Both
dropouts and the undo were on July 27: 11:46:31, 11:47:03 and 11:48:23 UTC in
the audit logs. Therefore the second enrolled period has July 27 as both start
and end. Enrollment records store dates; exact event ordering stays in the logs.

## Missing dropout audit

For the remaining Student, the local snapshot has only the successful LMS
creation audit. Searching the internal Student ID, User ID, external Student ID,
and dropout enrollment ID found no matching dropout audit. Other audit tables
in the snapshot concern curriculum or mentorship, not Student enrollment changes.

The creation audit and original memberships indicate enrollment on July 22.
Student.status is dropout; Batch/Grade memberships end July 27 and the current
dropout status row starts July 27. These are **consistent DB observations**, not
a recovered audit event. They cannot establish the actor, intent, or whether
any intermediate event is missing.

The report contains this evidence under `manual_review`, with
`automatic_repair=false`. A proposed exception would add an ended enrolled
period from July 22 to July 27 while preserving the current dropout, recording
DB evidence explicitly as its source. The user subsequently approved this fallback for this Student only. The
separate, identity-restricted `approved_db_exception.py` has now passed local
apply/rerun tests; see [APPROVED_DB_EXCEPTION.md](APPROVED_DB_EXCEPTION.md).
No synthetic dropout audit is created. This report recognizes its completed
repair audit; all other missing-audit cases remain report-only.

## Local commands

Use the existing snapshot's clone and Python environment from [README.md](README.md).

```sh
python utils/lms_enrolled_status/remaining_cases.py \
  --database dbservice_status_repair_remaining_20260917 \
  --limit 500 --output /private/tmp/remaining-report.json
shasum -a 256 /private/tmp/remaining-report.json
```

Review both the eligible row and the separate manual-review evidence. Only the
eligible repeated-cycle row is applicable:

```sh
python utils/lms_enrolled_status/remaining_cases.py \
  --database dbservice_status_repair_remaining_20260917 \
  --apply /private/tmp/remaining-report.json --approve-sha256 REVIEWED_SHA256 \
  --actor YOUR_EMAIL --output /private/tmp/remaining-result.json
```

The manifest binds this script and its imported single-dropout/initial helpers.
Changed code or evidence requires a fresh report. Ordered Student/enrollment
locks, serializable transactions, verification before commit, idempotent reruns,
and private exclusive-create output files follow the other utilities. Any
failure rolls back both new periods and the audit. Check successful command exit
and a fresh report; a result file alone is not proof of commit.

Maximum 500 Students per apply; report paging uses `--after-student-id` and
`next_after_student_id`. The missing-audit entry cannot be moved into `rows` to
bypass validation. Never point the loopback connection at a remote DB tunnel.

Run tests: `python -m unittest discover -s utils/lms_enrolled_status -v`.
Production apply and historical timestamp cleanup remain outside this task.
