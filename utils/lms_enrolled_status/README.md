# Missing LMS enrolled status records — local rehearsal

This utility covers only the first chart box: Students created through LMS in
2026–2027, still enrolled, with **no status enrollment records at all**. It leaves
Students with any status history (including the 152 accidental dropout/undo
cases) for separate work. School differences do not exclude a Student.

## Evidence and changes

The read-only report first recounts the box against the previous 36,817. It also
reports how many pass the stricter repair checks, exclusions, and malformed
creation audits. Never treat the page size as the total repair count.

Each candidate requires a unique successful LMS creation audit, matching
Student/User ownership, and original Batch and Grade enrollment records proving
the academic year and the same start date. Later Batch changes must match their
LMS audit chain. Ambiguous dates, status edits, dropout evidence, unexpected audit
actions, or inconsistent current memberships are excluded.

Apply adds one current `enrolled` status enrollment, with the **original Batch /
Grade start date**, plus a maintenance audit pointing to the creation audit.
`inserted_at` and `updated_at` record the actual repair time. It does not update
Student.status, existing enrollment records, School information, or old audits.

This version deliberately connects only to loopback PostgreSQL and databases
named `dbservice_status_repair_*`. It has no production URL or remote host option.
Do not use a local port forwarded to a remote database. Production execution is
outside this utility's current scope.

## Local workflow

Use the existing `utils/fetch-data.sh` to refresh a dedicated local database.
Keep that snapshot unchanged and clone it into a separate QA database for writes.
Use a PostgreSQL client matching the local server version. Never commit fetch
credentials, dumps, or row-level manifests.

Install Python 3 and `psycopg[binary]>=3.2,<4` in a virtual environment. Local
credentials default to postgres/postgres; `LOCAL_DB_PASSWORD` can override the
password. `--port` defaults to 5432.

```sh
python utils/lms_enrolled_status/repair.py \
  --database dbservice_status_repair_qa_20260917 \
  --limit 100 --output /private/tmp/enrolled-report.json
shasum -a 256 /private/tmp/enrolled-report.json
```

Review the summary and proposed rows, then pass the exact file hash:

```sh
python utils/lms_enrolled_status/repair.py \
  --database dbservice_status_repair_qa_20260917 \
  --apply /private/tmp/enrolled-report.json \
  --approve-sha256 REVIEWED_SHA256 --actor YOUR_EMAIL \
  --output /private/tmp/enrolled-result.json
```

Reports contain private Student/audit evidence; output files are created with
0600 permissions and cannot overwrite an existing file. The hash binds the
reviewed report; the report also binds the database and utility version. Any
code change requires regenerating the report.

Apply locks and revalidates a maximum of 500 Students in one transaction. Any
stale evidence or failed verification rolls back the entire batch. An unchanged
repeated apply returns `already_applied` without new rows. Statement timeout is
30 seconds and lock timeout is 2 seconds. A result file alone is not proof of a
commit: check the successful command exit and `Local repair committed` message,
then rerun the report. On an uncertain result, rerun the same approved manifest.

For subsequent report pages use `next_after_student_id` as `--after-student-id`;
stop when `more_candidates` is false. Each report recounts the remaining box.
Run a final report from the default cursor to ensure no candidates were missed.
No full-cohort apply is automatic.

## Verification

```sh
# Dedicated local integration database; tests use transaction-local TEMP tables.
createdb -h localhost -U postgres dbservice_status_repair_tests
python -m unittest discover -s utils/lms_enrolled_status -v
```

The tests cover historical dates, School independence, audited Batch replacement,
existing status history, ambiguous ownership/dates, stale-batch rollback,
idempotency, modified manifests, and local-only database guards.

The September 17, 2026 local rehearsal confirmed 37,255 LMS-created Students,
36,817 eligible missing-status cases (change: zero), and 438 excluded with
existing status history. A separate fresh local clone passed all 36,817 repairs across 74 batches and
repeat-apply of every batch with zero duplicates. Final missing count: zero.
Complete comparisons preserved every existing Student, enrollment, and audit
row. Apply commands totaled 26.09 seconds; reports, applies, and reruns took
4m57s, followed by 64 seconds of full-table verification. No production repair
was performed. See the private QA record for snapshot-specific evidence.

The separate second-box utility is documented in
[ACCIDENTAL_DROPOUT.md](ACCIDENTAL_DROPOUT.md). It corrects the 152 confirmed
accidental dropout/undo records; the first-box utility above is unchanged.

The third-box utility, which adds historical enrolled periods while preserving
current dropout records, is documented in [BEFORE_DROPOUT.md](BEFORE_DROPOUT.md).

The last two cases are covered in [REMAINING_CASES.md](REMAINING_CASES.md):
`remaining_cases.py` can repair the fully audited repeated cycle, while the
missing-audit Student is reported for a separate evidence/policy decision.

The user subsequently approved DB evidence for the one missing-audit Student.
The narrowly restricted utility is documented in
[APPROVED_DB_EXCEPTION.md](APPROVED_DB_EXCEPTION.md); no generic audit bypass exists.

See [WORKFLOW.md](WORKFLOW.md) for the five-box map and the required order when
combining status cleanup with the historical timestamp utility.
