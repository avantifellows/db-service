# Enrollment repair workflow

This folder contains the five separately reviewed chart groups for2026–2027
LMS-created Students. School differences are a separate issue. The scripts are local
by default; `--remote` runs them against another database (see below).

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

## Running against a remote database

Pass `--remote` and set `STATUS_REPAIR_DATABASE_URL`; `--database` must equal the
URL's database name. Connections are read-only unless applying an approved batch.
Reports bind `host:port/database`, so a local or staging report cannot be applied
to production. A remote apply locks at most 100 Students. The accidental-dropout
correction only proposes Students in `confirmed_accidental_dropouts.txt` (the 243
confirmed cases); any other dropout/undo is reported as `not_confirmed_accidental`.

`run_batches.py` runs one reviewed wave: it takes a 500-Student report, splits it
into batches of 100, applies each through the utility's own CLI, checks that a
rerun changes nothing, pauses, and stops at the first failure. Review a read-only
report first; the wave size is `--max-students`.

```sh
export STATUS_REPAIR_DATABASE_URL=...   # never commit or print it
python utils/lms_enrolled_status/run_batches.py --group repair --remote \
  --database prod_af_db --actor YOUR_EMAIL --out-dir /private/tmp/wave-01 \
  --max-students 500
```

Measured on staging from outside AWS: a report takes ~25 s, a 100-Student apply
~7 s. Outputs contain private Student evidence; keep them out of the repo.
