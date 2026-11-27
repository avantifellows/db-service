# Missing enrolled period before dropout — local rehearsal

`backfill_before_dropout.py` handles the third green box: **284** LMS-created
Students in 2026–2027 who have one audited dropout, no undo, and one current
dropout status record. Their earlier enrolled period is missing. This utility
preserves their dropout; it does **not** reactivate Students or memberships.

## Evidence and change

Require a unique creation audit and Student/User ownership, one enrolled →
dropout audit, and a matching current dropout enrollment. Its row ID, status,
dates and year must match the audit. The original Batch/Grade records establish
the initial enrollment date. Audited membership closure is reconstructed only
in memory to validate the pre-dropout state, including any earlier Batch edits.
School identity mismatch alone does not block the repair.

Add one historical status enrollment:

- Status: enrolled; `is_current=false`.
- Start: original Batch/Grade enrollment date.
- End: the audited dropout date (the current dropout period starts that day).
- `inserted_at` and `updated_at`: actual repair time.

Same-day enrollment/dropout can have equal start/end dates, matching the
service's date boundary convention. Never subtract a day or invent a time.
All existing rows and timestamps, including the current dropout status, remain
unchanged. Add one repair audit linking the new row to its creation audit,
dropout audit and current dropout enrollment.

Repeated dropout/undo histories, unexplained dropouts, extra status records,
conflicting dates/identity/membership evidence, or changes after dropout are not
automatically repaired. The report separates candidate count from eligible count.

## Run locally

Use a fresh clone of the existing local snapshot and the environment described
in [README.md](README.md). Do not fetch production again just to test this box.

```sh
python utils/lms_enrolled_status/backfill_before_dropout.py \
  --database dbservice_status_repair_dropped_20260917 \
  --limit 500 --output /private/tmp/before-dropout-report.json
shasum -a 256 /private/tmp/before-dropout-report.json
```

Review the recount against 284 and every proposed row before applying its hash:

```sh
python utils/lms_enrolled_status/backfill_before_dropout.py \
  --database dbservice_status_repair_dropped_20260917 \
  --apply /private/tmp/before-dropout-report.json --approve-sha256 REVIEWED_SHA256 \
  --actor YOUR_EMAIL --output /private/tmp/before-dropout-result.json
```

The local-only database guard, maximum 500-row transaction, ordered locks,
stale-evidence rejection, rollback, private output files and manifest approval
are the same as the first-box utility. The manifest binds both this file and
`repair.py`; code changes require a new report. An unchanged repeated apply
returns `already_applied`. Changed new records or surrounding evidence cause
rejection. A result file alone does not prove commit: check the successful exit
and `Local repair committed` message, then run a fresh report.

For multiple pages, pass `next_after_student_id` as `--after-student-id`. Finish
with a report from the default cursor. This version is local-only and must not
be used through a remote database tunnel.

Run the regression suite:

```sh
python -m unittest discover -s utils/lms_enrolled_status -v
```

Historical timestamp cleanup remains separate: this utility does not repair
existing `updated_at` values. Never reuse stale manifests from other repair
utilities after changing the data. No production apply is authorized here.
