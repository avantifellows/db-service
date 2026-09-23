# db-service Domain Context

This file defines the canonical language used by db-service. It includes the
Holistic Mentorship persistence and machine-contract terms approved for v1.

## Student Status History and Dropout Timestamps

last_updated: 2026-09-16

- LMS Add Student and Bulk Upload create a current `enrolled` status enrollment
  atomically with the Student, memberships, and creation audit.
- Full dropout ends the current status period and memberships, then creates a
  dropout period. Undo restores the same membership rows, ends the dropout period,
  and creates a new period matching the audited prior Student status (normally
  `enrolled`). Earlier status periods remain ended. The new period starts on the
  undo date; audits record its ID and the old status IDs that remain ended.
- Program-only dropout/undo leaves overall status history unchanged while another
  active Batch remains. Repeated undo, an extra current status row, or a missing
  configured prior status causes rejection; changes and audits remain atomic.
- Dropout/undo uses one second-precision UTC timestamp, captured after the Student
  lock and validation, for changed enrollments and the operation audit. Existing
  `inserted_at` values stay unchanged.
- [Historical timestamp repair](utils/dropout_timestamps/README.md) uses exact audit
  evidence, preserves valid later timestamps, and leaves incomplete or conflicting
  history unresolved. It changes only `updated_at` after separate approval of a
  fresh bounded manifest. No production repair has run; old inventory counts are
  stale and must not be used for apply.
- Existing-Student status backfill and unrelated import/re-enrollment APIs remain
  out of scope. No LMS code, request contract, or database schema change is needed.

Validation at `c76c6090`: 826 service tests, 24 repair tests, and configured checks
passed. Local Brave QA covered Add/Bulk, full and Program-only dropout/undo;
staging Add/cancel/two full cycles preserved history and an untouched control.

## Revised NVS Student Writes

- LMS is the authorization boundary for private NVS student writes; DB Service treats submitted actor metadata as trusted audit context.
- NVS school scope is established by matching school code and UDISE, current Program 64, and the student's Program 64 enrollment where applicable. The deployed Program 64 Product code is `TP-Async`, so it is not an NVS discriminator. Centre and `school.program_ids` are not part of this scope.
- PEN and Grade 10 Roll Number are the NVS creation identifiers in Approved mode only; in Phone mode the parent's phone is the creation identifier. APAAR remains historical and read-only.
- `CBSE` is stored as `CBSE`; `Others` is stored as null. NVS writes store gender `Other`, while legacy input `Others` is accepted.
- NVS batch selection is exact by program, grade, and normalized stream. Missing or ambiguous matches are errors; there is no fallback batch.
- NVS grade/stream edits and program dropout preserve enrollments and batch memberships belonging to other programs.

## Language

### Core identities

**User**:
The canonical LMS login identity referenced by staff and Student records.
_Avoid_: account record, email identity

**Student**:
The canonical learner record identified internally by `student.id` and linked
to exactly one User through `student.user_id`.
_Avoid_: using business `student.student_id` as a database join key

**Program**:
The canonical organizational scope that groups eligible Schools and Students.
Holistic Profile eligibility currently supports Program IDs `1`, `74`, `78`,
`88`, `94`, and `99`.
_Avoid_: hard-coded School allowlist

**Academic Year**:
The year boundary that scopes a Holistic Phase Plan and Mentor-Mentee Mapping.
_Avoid_: mentorship cycle

### Holistic Mentorship

**Holistic Mentorship**:
A mentorship domain independent of Academic Mentorship, with its own Phases,
Mappings, Notes, Historical Notes, Profiles, and regeneration records.
_Avoid_: extending or reusing Academic Mentorship records

**Phase Plan**:
The ordered Grade 11 and Grade 12 Holistic Phase definition for one Program and
Academic Year.
_Avoid_: phase template, static eight-phase list

**Phase**:
A stable item in a Phase Plan with a Grade, title, order, Locked/Open state,
Markdown Guidance, and one or more ordered Post-Session Questions.
_Avoid_: storing the displayed Phase number as identity

**Active Phase**:
The latest ordered Open Phase for a Grade in a Phase Plan, derived at read time.
_Avoid_: persisted active flag, manual Make Active action

**Phase State Transition**:
An audit event recording a Phase's Open/Locked change, human actor, and
occurrence time. The timeline lets LMS derive which Phase was Active when a
Mentor-Mentee Mapping began.
The authenticated email is the required actor snapshot; `actor_user_id` is an
optional link because LMS access does not require a canonical `user` row.
_Avoid_: persisted Active Phase, progress snapshot

**Phase Mutation Audit**:
A content-free actor/time record for Phase creation, definition edits, reorder,
or deletion. It stores no Guidance or Question snapshot and survives deletion
of a never-opened Phase.
The authenticated email is required and `actor_user_id` is optional.
_Avoid_: definition history, content snapshot

**Mentor-Mentee Mapping**:
A time-bounded assignment of one Student to one Mentor User at a School for a
Program and Academic Year. Ended rows remain as history. Assignment and end
events retain the authenticated actor email snapshot and may optionally link to
the canonical actor User; machine `assignment_source`, `end_source`, and
`end_reason` remain separate from human-entered assignment/end audit reasons.
ID-only system and reconciliation writers remain valid without email or human
reason snapshots.
_Avoid_: Academic Mentorship mapping, overwriting assignment history

**Post-Session Notes**:
The current official ordered answer set for one Mentee and stable Phase, with
optimistic revision and content-free mutation audit metadata.
_Avoid_: meeting record, answer revision archive

**Post-Session Note Audit**:
An immutable content-free event for a Notes mutation. Every event retains at
least one usable actor identity: a canonical `actor_user_id`, a nonblank
`actor_email` snapshot, or both. Email-only permission actors are valid, while
ID-only system and legacy writers remain valid.
_Avoid_: editable audit row, content snapshot

**Historical Holistic Notes**:
A provenance-bearing legacy answer set imported for a safely matched Student,
without inventing a canonical Phase, Mapping, or completion.
_Avoid_: migrated Post-Session Notes

**Student Profile**:
A journey-level set of ordered Question Set summaries generated from an
approved Profile Form and stored by immutable prompt/model configuration.
_Avoid_: raw questionnaire response, per-grade Profile

**Prompt Configuration**:
An immutable Prompt Version, exact template and hash, and exact model ID. One
registered configuration is explicitly Active; newest is never active by default.
_Avoid_: mutable prompt row, automatically latest prompt

**Regeneration Request**:
An idempotent request recorded for a human Admin to replace one Profile output
through the existing ETL flow while retaining the previous success on failure.
_Avoid_: synchronous generation request

**Profile Preflight**:
A bounded machine check that resolves a source User ID to one canonical Student
and verifies approved Form, entry Grade, Program, School, and current eligibility.
_Avoid_: best-effort identity matching

## Relationships

- A Program has one Phase Plan per Academic Year; a Phase Plan has ordered Phases.
- A Student has at most one active Mentor-Mentee Mapping per Academic Year.
- Post-Session Notes belong to one Student, one stable Phase, and their author.
- Mapping and Post-Session Note audit events retain immutable actor snapshots;
  canonical User links are optional where authenticated access has no User row.
- Mapping machine source/reason fields are never repurposed for human audit
  reasons; email and reason snapshots are nullable for system-created/ended
  rows and reject blank/whitespace values at the database boundary.
- A Student Profile belongs to the canonical Student journey and one immutable
  Prompt Configuration; older configurations remain retained.
- A Regeneration Request points to its human actor, Student, requested
  configuration, and ETL run/status.
- Holistic records may reference canonical User, Student, School, Program, and
  Academic Year identities but never Academic Mentorship-owned records.
- `db-service` owns schema, constraints, Profile machine APIs, and Student-side
  Mapping cleanup. `af_lms` owns product reads/writes; `etl-next` owns generation.

## Invariants

- Main Postgres is the sole durable Holistic Mentorship store.
- Displayed Phase number, Active Phase, Student Context, progress summaries, and
  Grade 12 placeholders are derived rather than stored.
- Open/Locked transition history is retained with actor/time so past Active Phase
  state can be reconstructed without storing an Active or progress snapshot.
- Phase definition mutations retain content-free actor/time audit without storing
  prior Guidance or Question versions.
- Post-Session Note audits are immutable, keep nullable canonical User references,
  require a canonical User ID or nonblank actor email, and allow 500-character
  human reasons for draft-erasure events.
- Raw questionnaire answers and rendered per-Student prompts are not persisted.
- Profile Program eligibility comes from the Student's one current School and
  that School's canonical Program IDs; it does not require a Program enrollment.
- Profile publication is atomic per Student and revalidates identity and scope.
- Student eligibility mutations end affected active Mappings atomically.
- Database sync includes all Holistic data for local and staging targets, including privacy-deletion markers. Oban job data is excluded from both targets.

## Example Dialogue

> **ETL engineer:** "Can I publish this Profile using the business Student ID?"
> **db-service engineer:** "No. Profile Preflight must resolve and return canonical
> `student.id`, and publication must revalidate it."

> **LMS engineer:** "Which Phase row is Active?"
> **db-service engineer:** "Derive the latest ordered Open Phase for that Grade;
> there is no stored active flag."

> **Operator:** "A new generation failed. Should the prior Profile be removed?"
> **db-service engineer:** "No. Keep the last successful Profile until an atomic
> replacement succeeds."

## Flagged Ambiguities

- Exact table decomposition and API route names follow existing Ecto and Phoenix
  conventions and are settled during the PRD and slice steps; the ownership and
  invariants above are fixed.
- The live staging deployment path may change, so release work must verify the
  currently active path rather than encode one historical workflow name.

### Missing initial enrolled status utility (2026-09-17)

`utils/lms_enrolled_status/repair.py` is a separate, local-only rehearsal utility
based after the historical timestamp repair stack. It recounts the 2026–2027
LMS-created, currently enrolled cohort with no status ER history, then proposes
bounded insert-only repairs from creation audits and original Batch/Grade dates.
School mismatch is not a blocker; all existing memberships and audits stay
unchanged. Students with existing status history, including the 152 accidental
undo cases, are out of scope. Fresh local production snapshot: 36,817 eligible,
unchanged from the chart. No production data repair has been run. See
`utils/lms_enrolled_status/README.md` for the report/apply safeguards and commands.

Full-cohort local follow-up: all 36,817 repaired in 74 batches, then every batch
replayed without duplicates; zero remaining. Existing Student/enrollment/audit
rows match the untouched snapshot. Apply commands totaled 26.09s; full loop
297.25s plus full-table verification 63.88s. No utility changes or production
access were needed.

### Accidental dropout/undo correction (2026-09-17)

The next chart box has 152 currently enrolled LMS-created Students, each with
one ended dropout status row and one linked dropout/undo cycle. The cohort owner
confirmed these were mistakes and should be continuously enrolled. Separate
`utils/lms_enrolled_status/cancel_accidental_dropout.py` corrects that row in
place to current enrolled from the original enrollment date, preserves the row
ID/inserted_at and old audit logs, and records before/after fields in a new repair
audit. School and other membership information remain untouched. This remains
local-only; production repair and coordination with the older historical
mutation timestamp utility are deferred. Operator guide:
`utils/lms_enrolled_status/ACCIDENTAL_DROPOUT.md`.

### Missing enrolled history before one dropout (2026-09-17)

`utils/lms_enrolled_status/backfill_before_dropout.py` handles the284 third-box
Students with one audited dropout and no undo. It adds one non-current enrolled
period from original enrollment date to dropout date plus a linked repair audit.
Student.status, all memberships, current dropout and all existing timestamps
remain unchanged. Repeated cycles and missing-audit cases remain separate.
Local-only report/apply and verification instructions: `BEFORE_DROPOUT.md` in
the same directory. No production repair or timestamp cleanup is included.

### Remaining singleton status cases (2026-09-17)

`remaining_cases.py` adds two non-current enrolled periods for the one completely
audited dropout→undo→dropout case, preserving both dropout rows and all prior
records. The other Student has no matching dropout audit in the local snapshot;
creation/membership/current-dropout dates support a possible July22–July27
period, but DB-evidence fallback is not approved. This case is report-only and
cannot be auto-applied. See `utils/lms_enrolled_status/REMAINING_CASES.md`.

September17 follow-up: user explicitly approved DB evidence for the singleton
Student20272025066071. `approved_db_exception.py` is pinned to that exact identity,
source audit and enrollment IDs/dates; adds only the July22→July27 ended enrolled
period plus a repair audit declaring the fallback and null dropout_audit_id.
Local apply/rerun and all-table preservation checks passed. The remaining-cases
report recognizes the completed exception.41 utility tests pass; no production
access or generic missing-audit bypass. All five chart groups now have utilities
and have passed separate local rehearsals.

### Coordinated status cleanup and timestamp repair (2026-09-17)

All five chart utilities are included in PR737's historical-utilities layer.
The timestamp report/coverage now validate accidental-status correction audits:
matched corrected status rows are preserve_status_correction, while original
membership mutation timestamps can still be repaired. Invalid/duplicate/stale
corrections are unresolved_status_correction and block related targets. New
backfill rows are not old audit targets. Run status cleanup first, then generate
fresh timestamp manifests; never reuse manifests across state changes. New
status utilities remain local-only. See utils/lms_enrolled_status/WORKFLOW.md.
