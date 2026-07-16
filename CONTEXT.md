# db-service Domain Context

This file defines the canonical language used by db-service. It includes the
Holistic Mentorship persistence and machine-contract terms approved for v1.

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
Holistic Mentorship v1 launches only for Program ID `1`.
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
Markdown Guidance, and one to four ordered Post-Session Questions.
_Avoid_: storing the displayed Phase number as identity

**Active Phase**:
The latest ordered Open Phase for a Grade in a Phase Plan, derived at read time.
_Avoid_: persisted active flag, manual Make Active action

**Phase State Transition**:
An audit event recording a Phase's Open/Locked change, human actor, and
occurrence time. The timeline lets LMS derive which Phase was Active when a
Mentor-Mentee Mapping began.
_Avoid_: persisted Active Phase, progress snapshot

**Phase Mutation Audit**:
A content-free actor/time record for Phase creation, definition edits, reorder,
or deletion. It stores no Guidance or Question snapshot and survives deletion
of a never-opened Phase.
_Avoid_: definition history, content snapshot

**Mentor-Mentee Mapping**:
A time-bounded assignment of one Student to one Mentor User at a School for a
Program and Academic Year. Ended rows remain as history.
_Avoid_: Academic Mentorship mapping, overwriting assignment history

**Post-Session Notes**:
The current official ordered answer set for one Mentee and stable Phase, with
optimistic revision and content-free mutation audit metadata.
_Avoid_: meeting record, answer revision archive

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
- Raw questionnaire answers and rendered per-Student prompts are not persisted.
- Profile publication is atomic per Student and revalidates identity and scope.
- Student eligibility mutations end affected active Mappings atomically.
- Production-to-staging sync excludes all Holistic table data after launch.

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
