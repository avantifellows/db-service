# Dropout enrollment timestamp repair

last_updated: 2026-09-12

Issue: https://github.com/avantifellows/db-service/issues/730

Dropout and undo previously changed enrollment state with `update_all` without
updating timestamps. The service now captures one UTC timestamp, at the schema's
second precision, after acquiring the Student lock and validating the operation.
Every changed enrollment and the dedicated operation audit uses that timestamp.
Existing enrollment creation timestamps and all state/identity rules are preserved.

## Read-only production findings

A single `REPEATABLE READ READ ONLY` production snapshot at **2026-09-12
07:05:40 UTC (12:35 IST)**, with a 10-second per-query timeout, found:

| Disposition | Enrollment rows |
| --- | ---: |
| Proposed timestamp repair | 11,369 |
| Preserve equal or later timestamp | 149 |
| Unresolved: current state differs from latest audit | 6 |
| Total exact audited targets | 11,524 |

The separate coverage query found zero orphan undo / missing-target audit shapes
in that snapshot. This does **not** mean every historical operation was audited.
Legacy global/import dropouts without exact enrollment audit IDs cannot be
reconstructed reliably and are outside automatic repair. Do not infer timestamps
from student creation, current Student status, or repair execution time.

The reported September 8 dropout/undo example resolves to the undo audit time;
its School enrollment's genuinely later September 9 update is preserved. The six
unresolved rows are batch enrollments whose latest audit records undo, but whose
current state is inactive with an end date. They require separate investigation.
The counts above describe the original September 12 query. They have not been
refreshed after moving consistency checks ahead of timestamp preservation;
some previously preserved rows may now be classified as unresolved. Regenerate
and review manifests with the current query before apply. Older manifests fail
the existing SQL-hash check.
No personal data or row-level production export is committed here. The private
report contains internal evidence/enrollment IDs and before snapshots. Live
counts will change; regenerate bounded manifests before seeking repair approval.
**No production repair was applied.**

## Evidence rules

`utils/dropout_timestamps/report.sql` expands exact batch and global enrollment
IDs in dropout audits, links undo via `dropout_audit_id`, and includes the ended
dropout-status enrollment on undo. It ranks the complete event history per
record **before** applying enrollment-ID pagination, including repeated cycles.
Audit timestamps, not requested dropout dates, supply repair times. End dates
only verify that the current state matches the operation's expected result.

Missing rows, mismatched Student/User ownership, bad undo links (including NULL),
duplicate target evidence anywhere in history, malformed target arrays/IDs,
wrong batch/status identities,
creation after evidence, missing timestamps, and inconsistent current state are
explicitly unresolved. Incomplete audit history blocks automatic repair for the
affected Student/User, including older valid events. Consistency checks run before
timestamp comparison: an equal/later timestamp is preserved only when the
record passes those checks. Inconsistent records remain unresolved and are
never repaired, even if their timestamps are already current. A global audit
lists exact row IDs but does not retain their prior group identities; the tool
can validate owner and current state, not reconstruct a missing group snapshot.
The report cannot prove the absence of historical unaudited writers. Human
review of each proposed batch remains required.

## Operator runbook

Use a private directory for manifests/verification (mode 0600), never commit them.
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
