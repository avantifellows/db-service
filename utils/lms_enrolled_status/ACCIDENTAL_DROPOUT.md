# Cancel confirmed accidental dropout periods — local rehearsal

`cancel_accidental_dropout.py` handles the **152** Students in the second green
box. The cohort owner confirmed these dropout/undo cycles were mistakes: their
intended status is continuously enrolled. This policy applies to this reviewed
cohort, **not to every undo in general**. This version is for local rehearsal
only, using the same local-database guard as `repair.py`.

## What changes

Each candidate has one LMS creation audit, one full dropout followed by its
linked undo, and exactly one ended dropout status enrollment. Student.status
must already be enrolled. Creation/Batch/Grade evidence must prove the original
2026–2027 enrollment date. The status row's identity, year, dropout date, undo
end date and insertion time must agree with the audit history. Repeated cycles,
extra status rows, contradictory transitions or uncertain evidence are excluded.

Correct the existing erroneous status row **in place**:

- Change its status group from dropout to enrolled.
- Set `is_current=true`, clear `end_date`, and use the original enrollment start.
- Set `updated_at` to the correction time; preserve its ID and `inserted_at`.
- Add a correction audit containing the complete before/after status-row fields
  used by the utility and links to the original creation, dropout and undo audits.

No status row is deleted or added. The original dropout/undo audit logs remain
unchanged, documenting both the mistake and its correction. Student, School,
Batch, Grade and Auth Group records stay unchanged. The stored row's creation
may therefore be later than its effective enrollment start; these dates represent
different things.

## Run locally

Use a fresh clone of the local snapshot. No new production read is needed.
Dependencies and connection defaults are in [README.md](README.md).

```sh
python utils/lms_enrolled_status/cancel_accidental_dropout.py \
  --database dbservice_status_repair_undo_20260917 \
  --limit 500 --output /private/tmp/undo-report.json
shasum -a 256 /private/tmp/undo-report.json
```

First review the recount against **152** and all exclusions. Then apply the exact
reviewed report:

```sh
python utils/lms_enrolled_status/cancel_accidental_dropout.py \
  --database dbservice_status_repair_undo_20260917 \
  --apply /private/tmp/undo-report.json --approve-sha256 REVIEWED_SHA256 \
  --actor YOUR_EMAIL --output /private/tmp/undo-result.json
```

The manifest binds the database and both Python source files. A changed helper
requires a new report. Apply locks the Students and enrollments, revalidates the
whole evidence, and verifies the correction before committing. Any failed row
rolls back the batch. Rerunning an unchanged manifest returns `already_applied`;
a changed correction or changed surrounding evidence fails closed. Output is
private (0600), exclusive-create, and flushed before commit. A file alone does
not prove a successful commit: check command success and a fresh report.

Maximum 500 Students per transaction; report pages support
`--after-student-id` using `next_after_student_id`. The final report should start
from the default cursor. Loopback database names must begin
`dbservice_status_repair_`; never connect through a remote database tunnel.

Run all utility tests with:

```sh
python -m unittest discover -s utils/lms_enrolled_status -v
```

## Relationship to historical timestamp repair

This corrects the **meaning** of an erroneous status row. The older timestamp
utility only repairs historical mutation timestamps. Do not reuse old timestamp
repair manifests after this cleanup, or overwrite the new correction timestamp
with the old undo time. How the timestamp utility should recognize these
correction audits remains a separate deferred follow-up. Neither this rehearsal
nor its local apply authorizes production changes.
