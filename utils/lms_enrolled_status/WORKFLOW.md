# Enrollment repair workflow

This folder contains the five separately reviewed chart groups for2026–2027
LMS-created Students. School differences are a separate issue. The new scripts
are currently **local-only rehearsal tools**, not production-enabled commands.

| Chart group | Script | Change |
| --- | --- | --- |
|36,817 no status history|repair.py|Add current enrolled period from original date.|
|152 accidental dropout→undo|cancel_accidental_dropout.py|Correct the existing status row to one continuous enrolled period; keep audit history.|
|284 one dropout, no undo|backfill_before_dropout.py|Add non-current enrolled period; preserve current dropout.|
|1 dropout→undo→dropout|remaining_cases.py|Add two non-current enrolled periods; preserve both dropout rows.|
|1 approved missing-audit exception|approved_db_exception.py|Add July22→July27 period for the single approved identity; record DB-evidence fallback explicitly.|

Read each linked runbook in README.md. Each utility first reports counts and
exclusions and saves a private, bounded, database/code-bound manifest. Review
it, then apply its exact SHA256. Revalidate immediately before writes, roll back
on stale evidence, and check reruns. Do not commit manifests or snapshot data.

## Order

1. Refresh the dedicated local snapshot only through the existing fetch script
   if a refresh is needed. Preserve it and clone it for local apply tests.
2. Run the five status utilities in the order above, reviewing each report.
3. Check each group's final report and all current status/history outcomes.
4. Generate new `utils/dropout_timestamps/report.sql` and `coverage.sql` results
   against that resulting state. Filter/review the intended Student cohort;
   the general timestamp report itself covers all logged dropout/undo history.
5. Apply only approved `proposed` timestamp targets, in batches of at most500.
   The152 corrected status rows must remain `preserve_status_correction`.
6. Verify only the intended timestamp columns changed; all new status periods,
   corrected status timestamps, Student rows and audit logs remain unchanged.

Status and timestamp manifests are snapshots. Once another utility changes the
reviewed evidence, an old manifest must be rejected rather than force-retried.

Merging the PR does not execute any repair. Production execution remains a
separate step requiring explicit approval of concrete, freshly reviewed data.
