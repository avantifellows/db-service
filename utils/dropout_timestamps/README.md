# Dropout timestamp repair utilities

These tools review and repair historical enrollment `updated_at` values using
exact dropout/undo audit evidence. They do not change Student status, memberships,
creation times, or add missing status enrollments. See [domain context](../../CONTEXT.md#student-status-history-and-dropout-timestamps)
for the live service behavior.

## Files

| File | Purpose |
| --- | --- |
| `repair.py` | CLI: saves a read-only report by default; applies a separately reviewed manifest only with its approval hash. |
| `report.sql` | Resolves exact enrollment targets across dropout/undo history, validates evidence, and classifies each row as proposed, preserved, or unresolved. Used by the CLI for both reporting and apply verification. |
| `coverage.sql` | Separate read-only check for malformed or missing-target audit shapes that may not appear in the paginated report. Run alongside the report for a full inventory. |
| `test_repair.py` | Local PostgreSQL integration tests for evidence validation, repeated cycles, retained status history, timestamp-only repair, rollback, and idempotency. |

## Evidence rules

`report.sql` expands exact batch and global enrollment
IDs in dropout audits, links undo via `dropout_audit_id`, and includes the ended
dropout-status enrollment on undo. It ranks the complete event history per
record **before** applying enrollment-ID pagination, including repeated cycles.
Audit timestamps, not requested dropout dates, supply repair times. End dates
only verify that the current state matches the operation's expected result.

Missing rows, mismatched Student/User ownership, bad undo links (including NULL),
duplicate target evidence anywhere in history, malformed target arrays/IDs,
non-positive IDs, invalid calendar dates, incomplete program/global target shapes,
wrong batch/status identities, creation after evidence, missing timestamps, and
inconsistent current state are explicitly unresolved. A malformed operation
blocks every exact target it names, including targets from later history; an
owner-scoped malformed operation also blocks that Student/User's history. When
owner identifiers are absent, exact target IDs are required to link the issue;
the report does not infer ownership for unrelated rows. A global audit requires
both global fields, allows an empty ended-enrollment array, and validates the
referenced dropout status enrollment's existence, owner, and type. Duplicate
undo audits for one dropout are unresolved; separate dropout/undo cycles remain
supported. Immutable owner, group, creation, and evidence checks cover the full
target history before the latest event is ranked, while current state checks use
only that latest event. Inconsistent records remain unresolved and are never
repaired, even if their timestamps are already current. A global audit lists
exact row IDs but does not retain their prior group identities; the tool can
validate owner and current state, not reconstruct a missing group snapshot.
The report cannot prove the absence of historical unaudited writers. Human
review of each proposed batch remains required.

## Operator runbook

Run commands from the repository root. Store manifests/verification privately
(the CLI creates files with mode 0600); never commit them.
Install `psycopg[binary]>=3.2,<4` in an isolated Python environment. Set
`DATABASE_URL` through the approved secret mechanism; never paste it into logs or
command arguments. The tool starts only a PostgreSQL connection, not the app.

Default mode is read-only, bounded to 100 rows (maximum 500):

```sh
python utils/dropout_timestamps/repair.py --limit 100 --output /private/path/page-001.json
python utils/dropout_timestamps/repair.py --after-id ENROLLMENT_CURSOR --limit 100 --output /private/path/page-002.json
```

Use `next_after_id` for the next page and continue until an empty page. For a
single consistent full inventory, execute `report.sql` repeatedly in one
`REPEATABLE READ READ ONLY` transaction, passing cursor and page size as `$1` and
`$2`; run `coverage.sql` in that transaction as well. Separate CLI invocations
are separate snapshots. The CLI manifests include the SQL hash and full before
snapshots. Only `proposed` rows are eligible for apply; preserved/unresolved rows
are never written. A manifest may be reduced to a reviewed subset, then hashed.

**Stop here for production until the user explicitly approves the concrete
manifest and its file SHA256. PR approval/deployment is not repair approval.**
After approval, the separate command is:

```sh
python utils/dropout_timestamps/repair.py --apply /private/path/reviewed.json --approve-sha256 APPROVED_SHA256 --output /private/path/verification.json
```

Apply accepts 1–500 distinct proposed rows. It verifies the approved file and
SQL hashes, uses a serializable transaction, locks Students then enrollments in
ID order, recomputes all latest audit evidence, and rejects any changed evidence
or snapshot. Each update compares the complete before row, sets only
`updated_at`, and verifies every other column is identical afterward. Any
mismatch, lock timeout, serialization failure, or verification failure rolls back
the entire batch. Review a newly generated manifest instead of force-retrying
stale evidence. An identical rerun recognizes already-repaired rows without
writing. Newer valid changes cause rejection, never reversal.

The verification file is fsynced before commit. If commit fails, that file alone
is **not proof of commit**: require the success message and rerun the read-only
report to confirm the proposed times now have `preserve_equal_or_later`. Keep
both the approved manifest and verification privately. Do not edit enrollment
state, Student records, or creation times as part of this repair.

## Local verification

Use a dedicated local database, never a production/staging URL:

```sh
MIX_TEST_PARTITION=_issue730 mix test
mix check
python -m unittest discover -s utils/dropout_timestamps -v
```

The Python integration tests deliberately hardcode localhost and
`dbservice_test_issue730`, ignore `DATABASE_URL`, and use temporary tables. They
exercise repeated cycles, later-update preservation, unresolved evidence,
changed-state/evidence rollback, manifest bounds, column preservation, and
idempotent apply. Controller/service regressions cover program-only, final-program,
undo, and unaudited global paths plus unrelated rows and `inserted_at`.

## Coordinate with enrollment-history cleanup

Run the reviewed status-history utilities in `utils/lms_enrolled_status/` first,
then generate **fresh** timestamp reports and coverage on the resulting data.
Old manifests are not reusable across cleanup; both the SQL hash and current
row/evidence snapshots are rechecked at apply. Do not rerun an old status-repair
manifest after timestamp repair changes its surrounding enrollment evidence.

The 152 accidental dropout corrections deliberately turn an ended dropout row
into a current enrolled row. A matching `student_accidental_dropout_correction`
audit now explains that state change. The report validates its source creation,
dropout and undo links, ownership, before/after identity, and current row contents
and timestamp. Valid corrected rows are `preserve_status_correction`: their
`updated_at` remains the actual correction time. Their original Batch/Grade/
School/Auth Group timestamp targets remain independently repairable from the
original operation audits. Those operations occurred even when the dropout was
a mistake; preserving that mutation time does not recreate a dropout period.

Missing, malformed, duplicated or mismatched correction evidence remains
unresolved. `unresolved_status_correction` blocks the affected owner/target and
is also surfaced by `coverage.sql`. The utility does not blindly trust an action
name or accept an unexplained change from dropout to enrolled.

New status rows from the insert-only backfills are not targets of old operation
audits, so their repair-time timestamps are untouched. The approved missing-audit
exception does not invent a dropout audit or authorize a guessed timestamp fix.
