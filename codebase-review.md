# db-service — Final Consolidated Codebase Review

**Reviewed by:** Claude (multi-agent swarm) + OpenAI Codex (independent, parallel)
**Date:** 2026-04-25
**Scope:** Full codebase — database layer, service layer, web/controllers, import workers, LiveView, infrastructure
**Phases:** Phase 1 (broad sweep) + Phase 2 (deep dive into memory, logic, concurrency, correctness)

---

## Table of Contents

1. [Security](#1-security)
2. [Data Integrity & Transactions](#2-data-integrity--transactions)
3. [N+1 Queries & Query Performance](#3-n1-queries--query-performance)
4. [Missing Database Indexes](#4-missing-database-indexes)
5. [Unbounded Queries & Missing Pagination](#5-unbounded-queries--missing-pagination)
6. [Inefficient Loops & Bulk Operations](#6-inefficient-loops--bulk-operations)
7. [Import Worker Performance](#7-import-worker-performance)
8. [Logic Bugs & Correctness](#8-logic-bugs--correctness)
9. [Infrastructure & Configuration](#9-infrastructure--configuration)
10. [Endpoint & Web Configuration](#10-endpoint--web-configuration)
11. [LiveView Issues](#11-liveview-issues)
12. [Dependencies & Code Quality](#12-dependencies--code-quality)
13. [Master Summary Table](#13-master-summary-table)
14. [Priority Action Plan](#14-priority-action-plan)
15. [Resolved](#15-resolved)

---

## 1. Security

### SEC-03 Unsafe dynamic field filtering (50+ controllers) [Critical]
*Found by: Phase 1 (Both) + Phase 2 (Claude)*

All controllers with index actions use this pattern:
```elixir
case String.to_existing_atom(key) do
  atom -> from(u in acc, where: field(u, ^atom) == ^value)
end
```

**Problems:**
1. Any query parameter becomes a WHERE clause — no allowlist of permitted filter fields
2. Clients can filter on any schema field, including unindexed ones causing full table scans
3. `String.to_existing_atom` raises `ArgumentError` on unknown atoms, crashing requests
4. Framework-injected params like `_format` or `_csrf_token` get treated as DB columns

Additionally, `apply_field_filter` in `lib/dbservice/resources.ex:948-956` uses a `try/rescue` around `String.to_existing_atom` for every filter parameter on every request. The `try/rescue` is expensive (creates exception objects), and unknown fields are silently dropped with no feedback.

**Fix:** Replace with explicit per-controller allowlists:
```elixir
@allowed_filters ~w(student_id stream father_name)

Enum.reduce(params, query, fn {key, value}, acc ->
  if key in @allowed_filters do
    atom = String.to_existing_atom(key)
    from(u in acc, where: field(u, ^atom) == ^value)
  else
    acc
  end
end)
```

### SEC-04 `debug_errors: true` in production [Critical]
*Found by: Phase 1 (Claude)*

**File:** `config/runtime.exs:27`

Leaks internal error details (stack traces, request data) to clients. Both a security issue and a minor performance concern.

**Fix:** Remove or set to `false`.

**Tracked in:** [#472](https://github.com/avantifellows/db-service/issues/472)

### SEC-05 `check_origin: false` in production [Critical]
*Found by: Phase 1 (Claude)*

**File:** `config/runtime.exs:28`

Disables WebSocket origin checking, enabling CSRF attacks against LiveView sessions.

**Fix:** Set `check_origin` to a list of allowed origins: `check_origin: ["https://#{host}"]`.

**Tracked in:** [#472](https://github.com/avantifellows/db-service/issues/472)

### SEC-06 LiveView `/imports` routes lack authentication [Critical]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice_web/router.ex:26-35`

Import management pages (`/imports`, `/imports/new`, `/imports/:id`) are in the `:browser` pipeline without the `:dashboard_auth` plug. Anyone with network access can view, create, and halt data imports.

**Fix:** Add `:dashboard_auth` to the LiveView scope, or implement a LiveView-compatible auth check in `mount/3`.

**Tracked in:** [#474](https://github.com/avantifellows/db-service/issues/474)

### SEC-08 Student identifier uniqueness enforced only in application code [Critical]
*Found by: Phase 1 (Codex)*

**Files:** `lib/dbservice/users.ex:347-368, 487-529`
**Migrations:** `20221121095220`, `20250623114448`, `20250825075810`

`student.student_id` and `student.apaar_id` have non-unique indexes only. Duplicate detection is done through separate reads before insert/update. Concurrent requests can both pass validation and create duplicates.

**Fix:** Add partial unique indexes:
```sql
CREATE UNIQUE INDEX ON student (student_id) WHERE student_id IS NOT NULL AND student_id <> '';
CREATE UNIQUE INDEX ON student (apaar_id) WHERE apaar_id IS NOT NULL AND apaar_id <> '';
```
Add matching `unique_constraint` calls in `Student.changeset/2`.

---

## 2. Data Integrity & Transactions

### TXN-01 `handle_batch_enrollment` — partial writes on failure [Critical]
*Found by: Phase 1 (Both) + Phase 2 (Both)*

**Files:**
- `lib/dbservice/services/batch_enrollment_service.ex:62-75, 80-93`
- `lib/dbservice/services/dropout_service.ex:43-65`
- `lib/dbservice/services/re_enrollment_service.ex:114-145`

All enrollment operations perform sequential DB writes (update existing -> insert new) without `Repo.transaction`. A crash between steps leaves permanently corrupted enrollment data.

Specific patterns:
- `handle_batch_enrollment`: Calls `update_existing_enrollments` (update_all) then `create_enrollment_record` (insert). If the insert fails, old enrollments are already marked `is_current=false`, leaving the student with **no current enrollment**.
- `handle_status_enrollment/5` (line 80) and `handle_grade_enrollment/5` (line 112): Same pattern.
- `create_dropout_enrollment` (`dropout_service.ex:43-65`): Three sequential operations — marks all current enrollments inactive, creates the dropout record, updates student status.
- `create_re_enrollment_records` (`re_enrollment_service.ex:114-145`): At minimum 6 separate DB operations with no transaction. The `with` chain provides error propagation but not rollback.

**Fix:** Wrap in `Repo.transaction/1` or use `Ecto.Multi`.

**Tracked in:** [#475](https://github.com/avantifellows/db-service/issues/475)

### TXN-02 Student/teacher/candidate creation leaves orphan user rows [Critical]
*Found by: Phase 1 (Claude) + Phase 2 (Codex)*

**Files:** `lib/dbservice/users.ex:292-300, 654-662`
**Also:** `lib/dbservice/users.ex:314` (update), `lib/dbservice/users.ex:676` (teacher update), `lib/dbservice/users.ex:811, 833` (candidate)

Creates a User record first, then a Student/Teacher/Candidate record. If the second insert fails, the User record is orphaned. Same issue in update flows.

**Fix:** Use `Ecto.Multi` for all user/student, user/teacher, and user/candidate create/update flows.

**Tracked in:** [#477](https://github.com/avantifellows/db-service/issues/477)

### TXN-03 Resource association updates can silently fail and lack transaction [Critical]
*Found by: Phase 2 (Both — Claude: missing transaction; Codex: ignored return values)*

**Files:** `lib/dbservice/resources.ex:491-501, 710-795`

`update_resource_and_associations/2` updates the resource, then calls `update_resource_associations/2` which deletes and re-creates curriculum, topic, chapter, and concept associations. Two distinct sub-issues:
1. **Silent failure (Codex):** Association write results are **ignored** — `{:ok, resource}` returned even if association creates failed. Existing associations can be deleted before failed recreation, causing data loss.
2. **No transaction (Claude):** The resource update and association changes are not wrapped in a transaction. A crash between steps leaves associations in a half-updated state.

**Fix:** Wrap in `Ecto.Multi`/`Repo.transaction`. Check and propagate every association operation result.

**Tracked in:** [#478](https://github.com/avantifellows/db-service/issues/478)

### TXN-04 Batch movement reports success even when DB operations fail [Critical]
*Found by: Phase 2 (Codex)*

**Files:**
- `lib/dbservice/utils/batch_movement.ex:66-78`
- `lib/dbservice/utils/teacher_batch_assignment.ex:55-66`

Return values from enrollment inserts, group-user updates, and student grade updates are **ignored**. Always returns `{:ok, "completed"}`.

**Fix:** Chain operations with `with`, return the first error, wrap in a transaction.

**Tracked in:** [#480](https://github.com/avantifellows/db-service/issues/480)

### TXN-05 `create_new_group_user` — enrollment record without group mapping [Critical]
*Found by: Phase 1 (Codex)*

**File:** `lib/dbservice/services/enrollment_service.ex:131-149`

Creates an `EnrollmentRecord` then creates a `GroupUser` outside a transaction. If the second insert fails, the enrollment record remains without the corresponding group mapping.

**Tracked in:** [#481](https://github.com/avantifellows/db-service/issues/481)

### TXN-06 Race condition in exclusive enrollment validation [Critical]
*Found by: Phase 1 (Codex)*

**File:** `lib/dbservice/services/enrollment_service.ex:62-74, 91-108`

Checks for existing current enrollment, then inserts/updates separately. Two concurrent requests can both see no conflict and create two current records.

**Tracked in:** [#482](https://github.com/avantifellows/db-service/issues/482)

**Fix (applies to all TXN-01 through TXN-06):** Wrap in `Repo.transaction/1` or use `Ecto.Multi`. Enforce exclusivity with database constraints (partial unique indexes) as a safety net.

### TXN-07 Race condition in batch movement [High]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice/utils/batch_movement.ex:57-81`

No database-level locking or transaction. Concurrent batch movements targeting the same student can corrupt enrollment data.

**Fix:** Wrap in a transaction with `SELECT ... FOR UPDATE` on enrollment records, or use advisory locks on user_id.

---

## 3. N+1 Queries & Query Performance

### NP1-01 ResourceJSON — 4+ DB queries per render call (MOST SEVERE) [Critical]
*Found by: Phase 1 (Both)*

**File:** `lib/dbservice_web/json/resource_json.ex:26-98`

Each call to `render/1` executes:
1. `Repo.one(from rt in ResourceTopic ...)` (line 28) — 1 query for topic_id
2. `Exams.get_exams_by_ids(resource.exam_ids)` (line 36) — 1 query
3. `Repo.one(from rt in ResourceChapter ...)` (line 40) — 1 query for chapter_id
4. `ResourceCurriculums.list_resource_curriculums_by_resource_id(resource.id)` (line 49) — 1 query

**Impact:** A response of 100 resources triggers **400+ queries** just in serialization.

Additionally, `render_problem/1` (line 105) and `problem_lang/1` (line 204) each call `Concepts.get_concept!` inside `Enum.map` — a **nested N+1 within an N+1**. Each concept is fetched individually per resource_concept row.

**Fix:** Preload all associations at the query level in the controller. The serializer should never execute DB queries.

**Tracked in:** [#476](https://github.com/avantifellows/db-service/issues/476)

### NP1-02 Lazy-loading Preloads in JSON Serializers (10+ serializers) [High]
*Found by: Phase 1 (Both) + Phase 2 (Claude)*

Every JSON serializer calls `Repo.preload` inside `render/1`. When called from `index` actions rendering N records, this creates N+1 queries per association.

| File | Line | Preload | Extra queries per item |
|---|---|---|---|
| `json/student_json.ex` | 22 | `Repo.preload(student, :user)` | 1 |
| `json/teacher_json.ex` | 14 | `Repo.preload(teacher, [:subject, :user])` | 2 |
| `json/school_json.ex` | 13 | `Repo.preload(school, :user)` | 1 |
| `json/candidate_json.ex` | 14 | `Repo.preload(candidate, [:subject, :user])` | 2 |
| `json/session_occurrence_json.ex` | 13, 32 | `Repo.preload(:session)`, `Repo.preload(:users)` | 2 |
| `json/chapter_json.ex` | 14 | `Repo.preload(chapter, :chapter_curriculum)` | 1 |
| `json/topic_json.ex` | 14 | `Repo.preload(topic, :topic_curriculum)` | 1 |
| `json/teacher_profile_json.ex` | 17, 35 | `Repo.preload(:user_profile)` (called twice in some paths) | 1-2 |
| `json/student_profile_json.ex` | 17, 47 | `Repo.preload(:user_profile)` (called twice in some paths) | 1-2 |
| `json/group_json.ex` | 22-76 | `Repo.get!` for child entity per group | 1+ |

Additionally, `batch_result` in `student_json.ex:85-104` re-preloads per student.

**Fix:** Move all preloads to the controller/context layer. Preload associations on the query result list before passing to the JSON serializer:
```elixir
students = Repo.all(query) |> Repo.preload(:user)
```

**Tracked in:** [#479](https://github.com/avantifellows/db-service/issues/479)

### NP1-03 `search_problems/1` — 1 + 2N queries per request [High]
*Found by: Phase 1 (Codex) + Phase 2 (Both)*

**File:** `lib/dbservice/resources.ex:1038-1061`

Fetches `ProblemLanguage` rows, then for each result calls `Repo.get!(Resource, problem_lang.res_id)` and another `Repo.all(...)` for `resource_curriculum`. That is `1 + 2N` queries per search request. 20 problems = 40 extra queries.

**Fix:** Build one query joining `problem_lang`, `resource`, and `resource_curriculum`. Or batch-fetch all resource IDs in one query and group in memory.

### NP1-04 `group_user_by_type?/2` — DB query per group_user in a loop [High]
*Found by: Phase 1 (Both) + Phase 2 (Both)*

**File:** `lib/dbservice/services/batch_enrollment_service.ex:141-170, 142, 157, 189-195`

`Enum.find(group_users, &group_user_by_type?(&1, type))` executes a `Repo.exists?()` query against the `groups` table for **every** group_user in the list.

**Impact:** For a CSV with 1000 rows and students averaging 4 group memberships, this produces ~8000 extra queries. The existing `get_group_user_by_user_id_and_type/2` already does a single joined query.

**Fix:** Use the existing joined query function, or preload the `group` association on group_users and filter in memory.

### NP1-05 `get_tests_containing_problems/1` — Full table scan in Elixir [High]
*Found by: Phase 1 (Both) + Phase 2 (Both)*

**File:** `lib/dbservice/resources.ex:205-239`

Loads ALL test resources via `Repo.all()`, then iterates in Elixir to check JSONB `type_params` content. O(N) with full row deserialization. Scales linearly with test count.

**Controller amplification:** `lib/dbservice_web/controllers/resource_controller.ex:171-204` — then loops over submitted problem IDs calling `Repo.get(Resource, problem_id)` for each one (N+1 on top of the full scan).

**Fix (interim):** Use a JSONB containment query and batch-fetch problem resources:
```elixir
from(r in Resource, where: r.type == "test" and fragment("?->>'problem_ids' @> ?", r.type_params, ^problem_id_json))
```
**Fix (long-term, Codex recommendation):** Normalize test-problem membership into a join table like `test_problem(test_resource_id, problem_resource_id, section_id, position)` with indexes on both IDs.

### NP1-06 `update_users_for_group` — SELECT + UPDATE per user [High]
*Found by: Phase 1 (Claude) + Phase 2 (Both)*

**File:** `lib/dbservice/utils/util.ex:82-106`

For every group_user, does a SELECT to fetch the user, then an UPDATE. If an auth group has 500 students, this generates 1000 queries.

**Fix:** Use a single `Repo.update_all` with a subquery:
```elixir
user_ids = from(gu in GroupUser, where: gu.group_id == ^group.id, select: gu.user_id)
from(u in User, where: u.id in subquery(user_ids))
|> Repo.update_all(set: [updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)])
```

### NP1-07 `get_problem/2` — over-fetches all resource curriculums, filters in memory [High]
*Found by: Phase 1 (Codex)*

**File:** `lib/dbservice_web/controllers/resource_controller.ex:814-846`

Preloads ALL `resource_curriculum` rows for a resource then `Enum.find`s the requested curriculum. For resources in many curricula, this over-fetches.

**Fix:** Join `resource_curriculum` in the query with `rc.curriculum_id == ^curriculum_id` to select only the matching row.

---

## 4. Missing Database Indexes

### IDX-01 Foreign key indexes absent on multiple join tables [High]
*Found by: Phase 1 (Both)*
*Verified against staging + production databases on 2026-05-02*

**Tracked in:** [#483](https://github.com/avantifellows/db-service/issues/483)

| Table | Missing Index | Used By |
|---|---|---|
| `resource_concept` | `resource_id`, `concept_id` | ResourceJSON rendering (every problem render) |
| `chapter_curriculum` | `chapter_id`, `curriculum_id` | ChapterJSON preload |
| `topic_curriculum` | `topic_id`, `curriculum_id` | TopicJSON preload |
| `school_batch` | `school_id`, `batch_id` | School-batch lookups |
| `problem_lang` | `res_id`, `lang_id` | Problem endpoint joins |
| `learning_objective` | `concept_id` | Concept lookups |
| `student_exam_record` | `student_id`, `exam_id` | Student exam queries |
| `school` | `user_id` | SchoolJSON user preload |
| `resource` | `teacher_id`, `code` | Resource lookups by code |
| `resource_curriculum` | `curriculum_id` | Curriculum resource queries |
| `cutoffs` | `college_id`, `branch_id`, `demographic_profile_id` | Cutoff queries |

### IDX-02 Missing composite indexes for hot queries [Critical]
*Found by: Phase 1 (Both)*

| Table | Columns | Rationale |
|---|---|---|
| `enrollment_record` | `(user_id, group_type, is_current)` | Multiple services filter on this combination constantly |
| `enrollment_record` | `(user_id, group_id, group_type, academic_year)` | Enrollment existence checks |
| `enrollment_record` | `(user_id, group_type, group_id, is_current)` | Batch enrollment validation |

Codex recommends partial unique indexes for exclusive current enrollment:
```sql
-- Only one current enrollment per (user, group_type) for exclusive types
CREATE UNIQUE INDEX ON enrollment_record (user_id, group_type)
WHERE is_current = true AND group_type IN ('school', 'grade', 'auth_group');
```

### IDX-03 Missing uniqueness constraints on join tables [Critical]
*Found by: Phase 1 (Codex)*

- `resource_concept` — no unique index on `(resource_id, concept_id)`, allows duplicate rows
- `problem_lang` — no unique index on `(res_id, lang_id)`, can cause ambiguous `Repo.one` results

**Fix:** Add unique indexes and use `on_conflict: :nothing` in bulk inserts.

### IDX-04 Missing indexes for JSONB and text search queries [Critical]
*Found by: Phase 1 (Codex)*

**Files:**
- `lib/dbservice/resources.ex:908-919` — searches `resource.code` and JSONB `resource.name`
- `lib/dbservice/resources.ex:931-945` — filters JSONB `name` and `type_params.resource_type`
- `lib/dbservice/resources.ex:1081-1089` — searches `problem_lang.meta_data` text/hint/solution

The `ILIKE '%term%'` and JSONB fragment queries will degrade to sequential scans.

**Fix:**
- Add `pg_trgm` indexes for text search on `resource.code`
- Add expression indexes for exact JSONB filters: `(type_params->>'resource_type')`
- Add GIN index on `problem_lang.meta_data` for JSONB containment queries

### IDX-05 Missing indexes for session search and imports [Critical]
*Found by: Phase 1 (Codex)*

- `session.platform_id`, `session.platform`, `session.is_active` — used in search/fetch paths, no indexes
- `imports.inserted_at`, `imports.status`, `imports.type` — dashboard queries order/filter by these, no indexes

**Fix:** Create a migration adding all missing indexes. This is the **highest-impact, lowest-risk** change in the entire review.

---

## 5. Unbounded Queries & Missing Pagination

### PAG-01 No default pagination limit across ALL 50+ controllers [High]
*Found by: Phase 1 (Both)*

Every `index` action accepts `offset` and `limit` as optional query parameters, but **none enforce a default or maximum limit**. When `limit` is omitted, `params["limit"]` is `nil` — Ecto treats this as no limit, returning the entire table.

**Affected controllers (all follow the same pattern):**
`user_controller`, `student_controller`, `group_user_controller`, `session_controller`, `alumni_controller`, `auth_group_controller`, `batch_controller`, `branch_controller`, `chapter_curriculum_controller`, `college_controller`, `concept_controller`, `curriculum_controller`, `enrollment_record_controller`, `exam_controller`, `form_schema_controller`, `grade_controller`, `language_controller`, `learning_objective_controller`, `problem_language_controller`, `resource_chapter_controller`, `resource_concept_controller`, `resource_curriculum_controller`, `resource_topic_controller`, `school_batch_controller`, `school_controller`, `status_controller`, `tag_controller`, `teacher_controller`, `topic_curriculum_controller`, `user_session_controller`, `cutoff_controller`, and more.

### PAG-02 37+ `list_*` context functions return entire tables [High]
*Found by: Phase 1 (Both) + Phase 2 (Claude)*

Functions like `list_all_users`, `list_student`, `list_session`, `list_enrollment_record`, etc. call `Repo.all(SchemaModule)` with no limit. `DataImport.list_imports/0` orders all imports by `inserted_at` with no limit.

**Additional files from Phase 2:** `lib/dbservice/users.ex:21-22, 148, 558`, `lib/dbservice/group_users.ex:22`, `lib/dbservice/sessions.ex:245`

### PAG-03 Resource-specific unbounded endpoints [High]
*Found by: Phase 1 (Codex)*

- `curriculum_resources/2` (`resource_controller.ex:501-516`) — pagination is optional; omitting `limit` returns all resources for a curriculum
- `fetch_problems/2` (`resource_controller.ex:745-786`) — joins resources, topics, resource_curriculums, problem_languages with no limit

**Fix:** Centralize pagination parsing in a shared helper:
```elixir
defp sanitize_pagination(params) do
  limit = min(String.to_integer(params["limit"] || "100"), 1000)
  offset = String.to_integer(params["offset"] || "0")
  %{"limit" => limit, "offset" => offset}
end
```

For high-volume tables (`user`, `student`, `enrollment_record`, `resource`, `session`), consider keyset pagination for stable performance.

---

## 6. Inefficient Loops & Bulk Operations

### LOOP-01 `update_school_enrollment` — fetch all then update one-by-one [High]
*Found by: Phase 1 (Both) + Phase 2 (Claude)*

**File:** `lib/dbservice/services/enrollment_service.ex:260-276`

```elixir
|> Repo.all()
|> Enum.each(fn record -> EnrollmentRecords.update_enrollment_record(record, %{...}) end)
```

**Fix:** Use `Repo.update_all`:
```elixir
from(er in EnrollmentRecord,
  where: er.user_id == ^user_id and er.group_id == ^school_id
    and er.group_type == "school" and er.academic_year != ^new_academic_year
    and er.is_current == true
)
|> Repo.update_all(set: [is_current: false, end_date: end_date])
```

### LOOP-02 `insert_resource_concepts` — N+1 inserts [High]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice_web/controllers/resource_controller.ex:395-400`

`Enum.each(concept_ids, fn concept_id -> create_resource_concept(...) end)` — separate INSERT per concept.

**Fix:** Use `Repo.insert_all` with `on_conflict: :nothing`.

### LOOP-03 `move_resources` — individual get + update per resource [High]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice_web/controllers/resource_controller.ex:249-256`

**Fix:** Batch-load resources, consider `Repo.update_all` for uniform changes.

### LOOP-04 Synchronous batch processing in request handlers [High]
*Found by: Phase 1 (Both)*

- `student_controller.ex:697` — `batch_process/2` iterates over batch_data synchronously, calling `Grades.get_grade_by_number` (line 715) and `Users.get_student_by_student_id` (line 723) per student
- `group_user_controller.ex:151` — same pattern

Large payloads hold the HTTP request process and database connections for a long time.

**Fix:** Offload to Oban workers (already set up for imports). Return a job ID and let clients poll for status. At minimum, add a configurable size limit on `batch_data`. Where synchronous processing is required, batch-prefetch existing students, users, grades, and groups, then use `insert_all`/`update_all`.

### LOOP-05 Student ID generation retry loop [High]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice_web/controllers/student_controller.ex:401-425`

`generate_new_student_id/1` starts with `counter = 1000` and calls `try_generate_id` recursively. Each attempt calls `check_if_generated_id_already_exists/1` which does a DB query. Worst case: 1000 DB queries in a single request.

**Fix:** Use a database sequence or generate IDs in a way that guarantees uniqueness without retry loops.

### LOOP-06 `update_current_status` — individual updates in loop [High]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice_web/controllers/student_controller.ex:684-689`

`Enum.reduce_while` calls `EnrollmentRecords.update_enrollment_record` for each record.

**Fix:** Use `Repo.update_all` with the list of record IDs.

### LOOP-07 Redundant `Groups.get_group!/1` calls in enrollment flows [Medium]
*Found by: Phase 1 (Claude) + Phase 2 (Claude)*

**Files:**
- `lib/dbservice/services/enrollment_service.ex:62-63, 131-132, 155-156` (2-3x per operation)
- `lib/dbservice/services/re_enrollment_service.ex:75, 213, 254, 295, 341, 405` (5-6x per operation)

Same group fetched repeatedly within a single operation.

**Fix:** Pass the already-fetched group struct through function parameters.

### LOOP-08 Import creation downloads Google Sheets synchronously in HTTP request [High]
*Found by: Phase 1 (Codex)*

**Files:** `lib/dbservice_web/controllers/import_controller.ex:21-144`, `lib/dbservice/data_import.ex:158-185, 314-319, 414-452`

The import controllers call `DataImport.start_import/1`, which obtains a Google token, downloads the CSV via `HTTPoison.get`, writes it to disk, and validates before queuing Oban. Slow Google responses or large files block the web request.

**Fix:** Create the import row and Oban job immediately. Move download and validation into the worker. Add HTTP timeouts to `HTTPoison.get/3`.

### LOOP-09 O(N^2) list concatenation in import worker [Medium]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/utils/import_worker.ex:287`

```elixir
{:cont, acc ++ [curriculum.id]}
```

`acc ++ [item]` copies the entire list on every iteration.

**Fix:** Prepend with `[curriculum.id | acc]` and reverse at the end.

---

## 7. Import Worker Performance

### IMP-01 Entire CSV loaded into memory despite streaming setup [Critical]
*Found by: Phase 1 (Claude) + Phase 2 (Both)*

**File:** `lib/dbservice/utils/import_worker.ex:598`

The CSV is decoded via a `Stream` pipeline but immediately materialized with `Enum.to_list()` before any processing. For a 50,000-row file, all rows and their parsed maps live simultaneously in the Oban worker process heap.

Additionally, `count_total_rows` (lines 1572-1617) reads the entire file separately via `File.read!()` + `String.split("\n")` — the file is fully loaded **twice**.

**Fix:** Process records lazily. Return `{records_stream, count}` from parsing, or count during `Enum.reduce_while`. For `count_total_rows`, use `File.stream!` with `Enum.count`.

**Tracked in:** [#485](https://github.com/avantifellows/db-service/issues/485)

### IMP-02 Per-row DB poll for halt status [Critical]
*Found by: Phase 1 (Both) + Phase 2 (Both)*

**File:** `lib/dbservice/utils/import_worker.ex:619-643`

`DataImport.get_import!(import_record.id)` called on every single row to check if import was stopped. For a 5000-row CSV = 5000 extra SELECT queries. With Oban concurrency of 10 and pool size of 10, this alone can saturate the DB pool.

**Fix:** Check every 50-100 rows, or use an ETS flag / PubSub message to signal stop:
```elixir
if rem(index, 50) == 0 do
  current_import = DataImport.get_import!(import_record.id)
  if current_import.status == "stopped", do: {:halt, ...}
end
```

**Tracked in:** [#486](https://github.com/avantifellows/db-service/issues/486)

### IMP-03 Per-row progress updates [Medium]
*Found by: Phase 1 (Both) + Phase 2 (Both)*

**Write side** (`lib/dbservice/utils/import_worker.ex:692, 1619-1633`):
Every successfully imported row calls `update_import_progress/2`, which writes `processed_rows` to the database AND broadcasts on the global `"imports"` PubSub topic. For a 1000-row import = 1000 DB UPDATEs + 1000 PubSub broadcasts.

**Read side** (`lib/dbservice_web/live/import_live/index.ex:110-142`):
Every broadcast triggers 2 DB queries (paginated list + status counts) in every connected LiveView session. All sessions subscribe to the global `"imports"` topic (line 12), so every browser processes messages from ALL active imports.

**Combined amplification:** N imported rows x M browser sessions x (1 DB write + 2 DB reads) = N + 2NM total queries.

**Fix:** Batch updates every 10-25 rows and on the final row:
```elixir
if rem(index, 25) == 0 or index == total_rows do
  update_import_progress(import_record, index)
end
```
Use per-import topics for detail pages. Include enough payload data to update assigns without re-querying.

**Tracked in:** [#487](https://github.com/avantifellows/db-service/issues/487)

### IMP-04 Double CSV parse [High]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice/utils/import_worker.ex:57-69, 104-134`

CSV parsed once in `count_total_rows` to count rows, then again in `process_import` to process. Doubles I/O and CPU cost.

**Fix:** Combine counting and parsing in a single pass.

### IMP-05 CSV validation reads entire file into memory [High]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice/data_import.ex:314-325`

`validate_csv_format` calls `File.read(path)` loading the entire CSV into memory just to validate headers.

**Fix:** Read only the first line for header validation; use `File.stream!` with `Enum.count` for row counting.

### IMP-06 Oban retries on non-transient failures [High]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice/utils/import_worker.ex:12`

`max_attempts: 3` retries the entire import on failures like invalid CSV format or missing data.

**Fix:** Return `{:cancel, reason}` for non-transient failures to prevent Oban from retrying.

### IMP-07 Static lookups not cached during import [High]
*Found by: Phase 1 (Both) + Phase 2 (implied)*

**Files:** `dropout_service.ex:20`, `batch_enrollment_service.ex:37`, `re_enrollment_service.ex:168`

`get_dropout_status_info()`/`get_enrolled_status_info()` query static reference data (statuses, groups) on every single row. During a 1000-row batch import, the same join query runs 1000 times.

**Fix:** Cache at the start of the import job and pass through processing. Or add an ETS-backed cache for low-churn lookup tables with short TTLs.

### IMP-08 Halting a pending import can delete the file before the worker opens it [High]
*Found by: Phase 2 (Codex)*

**Files:** `lib/dbservice/data_import.ex:286-302`, `lib/dbservice/utils/import_worker.ex:42-105`

`halt_import/1` sets status to "stopped" and calls `cleanup_import_file/1` (deletes CSV, sets filename to nil). The Oban worker doesn't check for "stopped" before processing — it calls `count_total_rows(import_record.filename)` which crashes on nil.

**Fix:** Make `perform/1` return `:ok` immediately when the import is "stopped" or has no filename.

### IMP-09 Import creation ignores failed Oban enqueue [High]
*Found by: Phase 2 (Codex)*

**File:** `lib/dbservice/data_import.ex:171-185`

`start_import/1` creates a pending import, calls `Oban.insert()`, **ignores the return value**, and returns `{:ok, import_record}`. If Oban enqueueing fails, the import stays "pending" forever.

**Fix:** Match on `{:ok, _job}`. On failure, mark the import as failed and return `{:error, reason}`.

### IMP-10 Double error logging and unbounded error_details [Medium]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice/utils/import_worker.ex:664-684, 709-733`

Both `log_import_error` and `handle_record_error` independently update the import record on error, causing duplicate writes. The `error_details` JSONB array has no size cap — a CSV with thousands of errors stores an ever-growing array.

**Fix:** Consolidate error handling into a single update path. Cap error_details (e.g., keep only the first 100 errors).

### IMP-11 `finalize_import` calls `length(records)` on full accumulated list [Medium]
*Found by: Phase 2 (Both)*

**File:** `lib/dbservice/utils/import_worker.ex:1644-1661`

`length/1` is O(N) on a list. The count is already known from the processing loop's `index` variable.

**Fix:** Pass the count from the processing phase.

### IMP-12 Naive `\n` split in fallback row counting [Low]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/utils/import_worker.ex:1599-1616`

Incorrectly counts CSV records with multi-line fields. Also loads file into memory in error path.

---

## 8. Logic Bugs & Correctness

### BUG-01 `validate_start_end_datetime` passes DateTime value instead of field atom to `add_error` [High]
*Found by: Phase 2 (Both)*

**File:** `lib/dbservice/utils/util.ex:58`

```elixir
add_error(changeset, start_time, "cannot be later than end time")
```

`start_time` is a DateTime value, not an atom. `add_error/3` expects `(changeset, :field_atom, message)`. This either silently stores the error under a wrong key or crashes.

**Fix:** `add_error(changeset, :start_time, "cannot be later than end time")`

Same bug in `validate_start_end_date/3` at line 64.

### BUG-02 Changeset validators `raise` instead of `add_error` [High]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/utils/util.ex:127-160`

```elixir
{:error, message} ->
  raise ArgumentError, message
```

Called inside `User.changeset/2` and `Student.changeset/2`. Invalid category/gender/stream in a CSV import crashes the entire process instead of producing a structured validation error.

**Fix:** Replace `raise` with `add_error(changeset, field, message)`.

### BUG-03 `String.to_atom/1` on DB column names — atom table leak [High]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice_web/controllers/user_controller.ex:265`

```elixir
Map.new(fn {k, v} -> {String.to_atom(k), v} end)
```

`String.to_atom/1` creates atoms that are never GC'd. Atom table is limited (1,048,576) — exhaustion crashes the VM.

**Fix:** Use `String.to_existing_atom/1` or keep keys as strings.

### BUG-04 Exclusive enrollment validation compares wrong ID domain [High]
*Found by: Phase 2 (Codex)*

**Files:** `lib/dbservice/services/enrollment_service.ex:63-66, 98, 136`

`handle_group_user_enrollment/1` loads a Group by `params["group_id"]` (which is `groups.id`), but `create_new_group_user/1` stores enrollment records with `group.child_id`. `validate_no_existing_enrollment/3` compares against `groups.id`. When `groups.id` differs from `groups.child_id`, validation gives wrong results.

**Fix:** Compare enrollment records against `group.child_id`, or pass both IDs explicitly.

### BUG-05 Future DateTime validation allows UTC timestamps up to 5h30m in the future [High]
*Found by: Phase 2 (Codex)*

**Files:** `lib/dbservice/utils/util.ex:17-18, 33`

`invalidate_future_date/2` computes IST by adding 5h30m to UTC, then compares. For actual UTC DateTime fields, timestamps 5 hours in the future pass validation.

**Fix:** Compare DateTime values to `DateTime.utc_now()` directly.

### BUG-06 Test problem order returned incorrectly [High]
*Found by: Phase 2 (Codex)*

**File:** `lib/dbservice/resources.ex:79-92`

`fetch_and_format_problems/3` extracts ordered problem IDs from a test, queries `WHERE r.id IN ^problem_ids`, then maps the database result order. SQL `IN` does not preserve input list order.

**Fix:** Build a map by resource ID, iterate over `problem_ids` to preserve test definition order.

### BUG-07 IST timezone offset stored as NaiveDateTime — effectively wrong UTC [Medium]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/utils/util.ex:16-38, 97-105`

IST offset `+05:30` hard-coded, then stored as NaiveDateTime. The `updated_at` column appears to be UTC but is actually IST — 5:30 hours ahead.

**Fix:** Always store UTC. Use proper timezone library for display-layer conversions.

### BUG-08 Missing `{:error, _}` clause in `process_with_batch_info` [Medium]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/utils/batch_movement.ex:47-55`

```elixir
case handle_batch_movement(...) do
  {:ok, _} -> {:ok, "..."}
  # No {:error, _} clause -> CaseClauseError at runtime
end
```

### BUG-09 Crash if `get_enrolled_status_info()` returns nil [Medium]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/utils/batch_movement.ex:106-115`

Pattern match `{status_id, status_group_type} = BatchEnrollmentService.get_enrolled_status_info()` raises `MatchError` if the "enrolled" status doesn't exist in DB.

### BUG-10 `rescue _` swallows all exceptions including DB errors [Medium]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/services/re_enrollment_service.ex:105-112`

```elixir
rescue
  _ -> "Unknown (ID: #{auth_group_id})"
```

Catches `DBConnection.ConnectionError`, OOM errors, and any critical failure silently.

**Fix:** Rescue only `Ecto.NoResultsError`.

### BUG-11 Import `start_row` parsing can crash [Medium]
*Found by: Phase 2 (Codex)*

**File:** `lib/dbservice/data_import.ex:164`

`String.to_integer(start_row)` raises `ArgumentError` on malformed input, bypassing `{:error, reason}` error handling.

**Fix:** Use `Integer.parse/1` and validate result.

### BUG-12 Generic error message when changeset has no errors [Low]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/services/dropout_service.ex:79-85`

Returns "Failed to process dropout" with zero diagnostic value.

---

## 9. Infrastructure & Configuration

### CFG-01 DB pool size equals Oban queue concurrency — zero headroom [Critical]
*Found by: Phase 1 (Both) + Phase 2 (Claude)*

**Files:** `config/config.exs:60-69`, `config/dev.exs:10`, `config/runtime.exs:6-9`

Pool size = 10, Oban imports queue = 10. A burst of imports saturates the pool entirely. Web API requests then queue at `queue_target: 15_000` (15 seconds!) before getting a DB connection.

**Fix:** Reduce Oban to `[imports: 3]` or `[imports: 5]`. Ensure import concurrency is at most 30-50% of pool size. Consider a separate Oban repo for background jobs.

**Tracked in:** [#484](https://github.com/avantifellows/db-service/issues/484)

### CFG-02 Excessively high query timeout [Medium]
*Found by: Phase 1 (Both)*

**File:** `config/config.exs:60-63`

`timeout: 120_000` (120 seconds) globally masks slow queries and can cause connection pool exhaustion if multiple slow queries hold connections for 2 minutes each.

**Fix:** Reduce to 15-30 seconds globally. Pass `timeout: 120_000` explicitly for known long operations (CSV imports, bulk processing).

### CFG-03 Excessively high queue_target and queue_interval [Medium]
*Found by: Phase 1 (Both)*

**File:** `config/config.exs:62-63`

`queue_target: 15_000` (vs default 50ms) and `queue_interval: 100_000` (vs default 1000ms) completely hide pool saturation. Requests wait up to 15 seconds for a connection without any warning.

**Fix:** Revert closer to defaults: `queue_target: 500`, `queue_interval: 5_000`. Add telemetry alerts for DB queue time.

### CFG-04 Missing Oban Lifeline plugin [Medium]
*Found by: Phase 1 (Claude)*

**File:** `config/config.exs:68`

No `Oban.Plugins.Lifeline` — jobs stuck in `executing` state after crash/deploy are never rescued.

**Fix:** Add `{Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}`.

### CFG-05 No health check endpoint [Medium]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice_web/router.ex`

No `/health` or `/ready` endpoint for load balancers/container orchestrators.

### CFG-06 No production connection lifecycle settings [Medium]
*Found by: Phase 1 (Claude)*

**File:** `config/runtime.exs:7-9`

No `idle_interval`, `connect_timeout`, or `socket_options: [:keepalive]`. Idle connections are never recycled, which causes stale connections in cloud environments.

**Fix:** Add to production Repo config:
```elixir
connect_timeout: 10_000,
idle_interval: 60_000,
socket_options: [:keepalive]
```

### CFG-07 No application caching layer [Medium]
*Found by: Phase 1 (Codex)*

**Files:** `mix.exs`, `lib/dbservice/application.ex`

No Cachex/Nebulex/ETS-backed cache, while stable lookup entities (grades, statuses, languages, auth groups) are queried repeatedly in imports and batch endpoints.

**Fix:** Add an ETS-backed cache for low-churn lookup tables. Invalidate on writes or use short TTLs.

### CFG-08 Supervisor max_restarts not tuned [Medium]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice/application.ex:32`

Default `max_restarts: 3` in 5 seconds. If Goth (Google Auth) crashes 4 times, the entire application supervisor terminates, taking down the web server.

**Fix:** Increase to `max_restarts: 10, max_seconds: 30`, or isolate Goth under a separate supervisor.

### CFG-09 Deprecated `:warn` log level [Low]
*Found by: Phase 1 (Claude)*

**File:** `config/prod.exs:15`

`:warn` is deprecated in Elixir 1.15+. Use `:warning`.

### CFG-10 Repo module has no optimizations [Low]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice/repo.ex`

No `prepare: :unnamed` (needed for PgBouncer in transaction mode), no `default_options/1` callback. Consider adding if using a connection pooler.

---

## 10. Endpoint & Web Configuration

### WEB-01 gzip disabled for static files [Medium]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice_web/endpoint.ex:22`

`gzip: false` — pre-compressed static assets (Swagger UI, LiveView assets) not served even when `mix phx.digest` generates them.

**Fix:** Change to `gzip: true`.

### WEB-02 No response compression for API responses [Medium]
*Found by: Phase 1 (Claude)*

No `Plug.Compress` for dynamic API responses. JSON payloads (which can be large for list endpoints) are sent uncompressed.

**Fix:** Add `plug Plug.Compress` before the router plug.

### WEB-03 `cache_static_manifest` commented out [Medium]
*Found by: Phase 1 (Claude)*

**File:** `config/prod.exs:12`

No cache-busted static assets — clients re-download CSS/JS on every visit.

**Fix:** Uncomment: `config :dbservice, DbserviceWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"`.

### WEB-04 No rate limiting [Medium]
*Found by: Phase 1 (Claude)*

No rate limiting on any endpoint. Batch processing endpoints (`/api/student/batch-process`, `/api/group-user/batch-process`) and write-heavy endpoints are particularly vulnerable.

**Fix:** Add a rate-limiting plug such as `hammer` or `ex_rated` to the `:api` pipeline.

### WEB-05 No ETag / conditional request support [Low]
*Found by: Phase 1 (Claude)*

No ETag support for GET endpoints returning large, stable datasets (curricula, subjects, chapters).

### WEB-06 No request body size limit for batch endpoints [Medium]
*Found by: Phase 1 (Claude)*

**File:** `lib/dbservice_web/endpoint.ex:39`

`Plug.Parsers` uses default 8MB limit. Batch processing endpoints accept arbitrary-sized arrays.

**Fix:** Add explicit body size limits and validate batch array sizes in controllers.

---

## 11. LiveView Issues

### LV-01 Full page refresh on every PubSub message [Medium]
*Found by: Phase 1 (Claude) + Phase 2 (Both — detailed amplification analysis)*

**File:** `lib/dbservice_web/live/import_live/index.ex:110-141`

Every `{:import_updated, import_id}` message triggers 2 database queries (list + count). All sessions subscribe to the global `"imports"` topic (line 12), so every browser processes messages from ALL active imports. Many simultaneous imports can cause excessive load.

**Fix:** Debounce updates or only refresh if the import_id is on the current page. Use per-import topics for detail pages.

### LV-02 Protected import submission can leave the form stuck [Critical]
*Found by: Phase 2 (Codex)*

**Files:** `lib/dbservice_web/live/import_live/new.ex:56, 79`

The form sets `submitted: true`, then protected import types push a browser event for an authenticated endpoint. If the browser auth flow is canceled or fails, `submitted` is never reset — the form stays stuck.

**Fix:** Don't set `submitted: true` for the push-event path, or add a client callback to reset on cancel/failure.

### LV-03 Show page reparses error_details on every render [Medium]
*Found by: Phase 2 (Codex)*

**File:** `lib/dbservice_web/live/import_live/show.ex:24, 69, 77, 267`

Reloads full import on every update. Template calls `parse_error_details(@import.error_details)` during render, which may call `Jason.decode/1` for every binary detail. For failed imports with large error arrays, this repeatedly wastes CPU and memory.

**Fix:** Normalize error details before assigning. Render only a bounded slice.

### LV-04 Stop modal can crash on malformed or stale IDs [Medium]
*Found by: Phase 2 (Codex)*

**File:** `lib/dbservice_web/live/import_live/index.ex:82-94`

`String.to_integer(import_id)` can raise on malformed client input. If the ID parses but is not on the current page, `selected_import` is nil, and the confirm path dereferences nil.

**Fix:** Use `Integer.parse/1`, guard the confirm path.

### LV-05 Pagination state becomes stale after PubSub refresh [Medium]
*Found by: Phase 2 (Codex)*

**File:** `lib/dbservice_web/live/import_live/index.ex:112, 136`

`handle_info/2` refreshes imports but discards `_total_count`. If imports are added/removed, `total_count` and `total_pages` stay stale.

---

## 12. Dependencies & Code Quality

### DEP-01 File-based logger configured globally (including production) [Low]
*Found by: Phase 1 (Claude)*

**File:** `config/config.exs:34-41`

`LoggerFileBackend` writing to `logs/info.log` in all environments. In production containers, the file grows unbounded with no rotation.

**Fix:** Move to `dev.exs` only. For production, rely on `:console` backend and container log aggregation.

### DEP-02 `logger_file_backend` is unmaintained [Low]
*Found by: Phase 1 (Claude)*

**File:** `mix.exs:54`

Unmaintained package with known issues on Elixir 1.15+ logger architecture. Migrate to Erlang's built-in `:logger_std_h` handler.

### DEP-03 Duplicate HTTP client libraries [Low]
*Found by: Phase 1 (Claude)*

**File:** `mix.exs:59, 63`

Both `httpoison` and `hackney` listed explicitly. Goth also pulls in Finch. Three HTTP client libraries add compile time and memory overhead.

**Fix:** Remove explicit `hackney` dep (HTTPoison already declares it). Long-term, consolidate on Finch.

### DEP-04 `calendar` dependency likely unnecessary [Low]
*Found by: Phase 1 (Claude)*

**File:** `mix.exs:55`

`calendar ~> 1.0.0` is largely superseded by Elixir's built-in `DateTime`/`Calendar` modules.

### DEP-05 SSL verification disabled for build tools [Low]
*Found by: Phase 1 (Claude)*

**File:** `config/config.exs:81, 91`

`ssl: [verify: :verify_none]` for Tailwind and esbuild downloads. Low priority but should be fixed with proper CA bundle config.

### DEP-06 Duplicate regex match then scan [Low]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/data_import.ex:490-491`

Two identical regex operations. Use single `Regex.run/2`.

### DEP-07 Linear scan with `String.upcase` per validation [Low]
*Found by: Phase 2 (Claude)*

**File:** `lib/dbservice/utils/util.ex:165-170`

Use compile-time MapSet of upcased values.

### DEP-08 Duplicate helper functions across LiveView modules [Low]
*Found by: Phase 2 (Claude)*

**Files:** `lib/dbservice_web/live/import_live/index.ex:503-514`, `show.ex:315-325`

`format_date`, `format_time`, `pad` duplicated. Extract to shared module.

---

## 13. Master Summary Table

| ID | Severity | Category | File(s) | Issue | Source |
|----|----------|----------|---------|-------|--------|
| SEC-03 | Critical | Security | 50+ controllers, `resources.ex:948-956` | Unsafe dynamic field filtering, no allowlist | Phase 1 (Both) + Phase 2 (Claude) |
| SEC-04 | Critical | Security | `runtime.exs:27` | `debug_errors: true` in production | Phase 1 (Claude) |
| SEC-05 | Critical | Security | `runtime.exs:28` | `check_origin: false` in production | Phase 1 (Claude) |
| SEC-06 | Critical | Security | `router.ex:26-35` | LiveView `/imports` routes unauthenticated | Phase 1 (Claude) |
| SEC-08 | Critical | Security | `users.ex:347-368, 487-529` | Student ID uniqueness not DB-enforced | Phase 1 (Codex) |
| TXN-01 | Critical | Data Integrity | `batch_enrollment_service.ex`, `dropout_service.ex`, `re_enrollment_service.ex` | Multi-step enrollment writes without transaction | Phase 1 + 2 (Both) |
| TXN-02 | High | Data Integrity | `users.ex:292-300, 654-662, 811, 833` | Orphan user rows on failed student/teacher/candidate create | Phase 1 (Claude) + Phase 2 (Codex) |
| TXN-03 | Critical | Data Integrity | `resources.ex:491-501, 710-795` | Resource association updates silently fail + no txn | Phase 2 (Both) |
| TXN-04 | Critical | Data Integrity | `batch_movement.ex:66-78`, `teacher_batch_assignment.ex:55-66` | Success returned when DB ops fail | Phase 2 (Codex) |
| TXN-05 | High | Data Integrity | `enrollment_service.ex:131-149` | Enrollment record without group mapping | Phase 1 (Codex) |
| TXN-06 | Critical | Data Integrity | `enrollment_service.ex:62-74, 91-108` | Race condition in exclusive enrollment | Phase 1 (Codex) |
| TXN-07 | High | Data Integrity | `batch_movement.ex:57-81` | Race condition in batch movement | Phase 1 (Claude) |
| NP1-01 | Critical | N+1 Query | `resource_json.ex:26-98` | 4+ DB queries per resource render | Phase 1 (Both) |
| NP1-02 | High | N+1 Query | 10+ JSON serializers | Lazy-loading preloads in render/1 | Phase 1 (Both) + Phase 2 (Claude) |
| NP1-03 | High | N+1 Query | `resources.ex:1038-1061` | search_problems 1+2N queries | Phase 1 (Codex) + Phase 2 (Both) |
| NP1-04 | High | N+1 Query | `batch_enrollment_service.ex:141-170` | DB query per Enum.find element | Phase 1 + 2 (Both) |
| NP1-05 | High | N+1 Query | `resources.ex:205-239` | Full table scan for test-problem lookup | Phase 1 + 2 (Both) |
| NP1-06 | High | N+1 Query | `util.ex:82-106` | SELECT + UPDATE per group user | Phase 1 (Claude) + Phase 2 (Both) |
| NP1-07 | High | N+1 Query | `resource_controller.ex:814-846` | Over-fetches all resource curriculums | Phase 1 (Codex) |
| IDX-01 | High | Missing Index | 12+ tables | Foreign key indexes absent on join tables | Phase 1 (Both) |
| IDX-02 | Critical | Missing Index | `enrollment_record` | Missing composite indexes for hot queries | Phase 1 (Both) |
| IDX-03 | Critical | Missing Index | `resource_concept`, `problem_lang` | Missing uniqueness constraints on join tables | Phase 1 (Codex) |
| IDX-04 | Critical | Missing Index | `resource`, `problem_lang` | Missing JSONB/text search indexes | Phase 1 (Codex) |
| IDX-05 | Critical | Missing Index | `session`, `imports` | Missing indexes for session search/imports | Phase 1 (Codex) |
| PAG-01 | High | Pagination | 50+ controllers | No default pagination limit | Phase 1 (Both) |
| PAG-02 | High | Pagination | 37+ context functions | Unbounded `Repo.all` on full tables | Phase 1 (Both) + Phase 2 (Claude) |
| PAG-03 | High | Pagination | `resource_controller.ex` | Resource-specific unbounded endpoints | Phase 1 (Codex) |
| LOOP-01 | High | Bulk Ops | `enrollment_service.ex:260-276` | Fetch all then update one-by-one | Phase 1 + 2 (Both) |
| LOOP-02 | High | Bulk Ops | `resource_controller.ex:395-400` | N+1 inserts for resource concepts | Phase 1 (Claude) |
| LOOP-03 | High | Bulk Ops | `resource_controller.ex:249-256` | Individual get + update per resource move | Phase 1 (Claude) |
| LOOP-04 | High | Bulk Ops | `student_controller.ex:697`, `group_user_controller.ex:151` | Synchronous batch processing in request handlers | Phase 1 (Both) |
| LOOP-05 | High | Bulk Ops | `student_controller.ex:401-425` | Student ID generation retry loop (up to 1000 queries) | Phase 1 (Claude) |
| LOOP-06 | High | Bulk Ops | `student_controller.ex:684-689` | Individual enrollment updates in loop | Phase 1 (Claude) |
| LOOP-07 | Medium | Bulk Ops | `enrollment_service.ex`, `re_enrollment_service.ex` | Redundant group fetches (2-6x per op) | Phase 1 + 2 (Claude) |
| LOOP-08 | High | Bulk Ops | `import_controller.ex`, `data_import.ex` | Sync Google Sheets download in HTTP request | Phase 1 (Codex) |
| LOOP-09 | Medium | Bulk Ops | `import_worker.ex:287` | O(N^2) list concatenation | Phase 2 (Claude) |
| IMP-01 | Critical | Import Worker | `import_worker.ex:598` | CSV loaded into memory + double scan | Phase 1 + 2 (Both) |
| IMP-02 | Critical | Import Worker | `import_worker.ex:619-643` | Per-row DB poll for halt status | Phase 1 + 2 (Both) |
| IMP-03 | High | Import Worker | `import_worker.ex:1619-1633`, `import_live/index.ex:110` | Per-row progress update + PubSub amplification | Phase 1 + 2 (Both) |
| IMP-04 | High | Import Worker | `import_worker.ex:57-69, 104-134` | Double CSV parse | Phase 1 (Claude) |
| IMP-05 | High | Import Worker | `data_import.ex:314-325` | CSV validation reads entire file into memory | Phase 1 (Claude) |
| IMP-06 | High | Import Worker | `import_worker.ex:12` | Oban retries on non-transient failures | Phase 1 (Claude) |
| IMP-07 | High | Import Worker | `dropout_service.ex:20`, `batch_enrollment_service.ex:37` | Static lookups not cached during import | Phase 1 (Both) only |
| IMP-08 | High | Import Worker | `data_import.ex:286-302` | File deleted before worker opens it | Phase 2 (Codex) |
| IMP-09 | High | Import Worker | `data_import.ex:171-185` | Failed Oban enqueue ignored | Phase 2 (Codex) |
| IMP-10 | Medium | Import Worker | `import_worker.ex:664-684, 709-733` | Double error logging + unbounded error_details | Phase 1 (Claude) |
| IMP-11 | Medium | Import Worker | `import_worker.ex:1644-1661` | O(N) length on full record list | Phase 2 (Both) |
| IMP-12 | Low | Import Worker | `import_worker.ex:1599-1616` | Naive \\n split in fallback counting | Phase 2 (Claude) |
| BUG-01 | High | Logic Bug | `util.ex:58, 64` | add_error passed DateTime not atom | Phase 2 (Both) |
| BUG-02 | High | Logic Bug | `util.ex:127-160` | Validators raise instead of add_error | Phase 2 (Claude) |
| BUG-03 | High | Logic Bug | `user_controller.ex:265` | String.to_atom atom table leak | Phase 2 (Claude) |
| BUG-04 | High | Logic Bug | `enrollment_service.ex:63-66, 98, 136` | Wrong ID domain in enrollment validation | Phase 2 (Codex) |
| BUG-05 | High | Logic Bug | `util.ex:17-33` | Future date validation off by 5h30m | Phase 2 (Codex) |
| BUG-06 | High | Logic Bug | `resources.ex:79-92` | Test problem order not preserved | Phase 2 (Codex) |
| BUG-07 | Medium | Logic Bug | `util.ex:16-38, 97-105` | IST stored as NaiveDateTime (wrong UTC) | Phase 2 (Claude) |
| BUG-08 | Medium | Logic Bug | `batch_movement.ex:47-55` | Missing error clause -> CaseClauseError | Phase 2 (Claude) |
| BUG-09 | Medium | Logic Bug | `batch_movement.ex:106-115` | Crash on nil status info | Phase 2 (Claude) |
| BUG-10 | Medium | Logic Bug | `re_enrollment_service.ex:105-112` | rescue _ swallows all exceptions | Phase 2 (Claude) |
| BUG-11 | Medium | Logic Bug | `data_import.ex:164` | start_row parse crash | Phase 2 (Codex) |
| BUG-12 | Low | Logic Bug | `dropout_service.ex:79-85` | Generic error message, no diagnostics | Phase 2 (Claude) |
| CFG-01 | High | Infrastructure | `config.exs:60-69`, `runtime.exs:6-9` | Pool size = Oban concurrency, zero headroom | Phase 1 + 2 (Both) |
| CFG-02 | Medium | Infrastructure | `config.exs:60-63` | 120s query timeout masks slow queries | Phase 1 (Both) |
| CFG-03 | Medium | Infrastructure | `config.exs:62-63` | queue_target 15s hides pool saturation | Phase 1 (Both) |
| CFG-04 | Medium | Infrastructure | `config.exs:68` | Missing Oban Lifeline plugin | Phase 1 (Claude) |
| CFG-05 | Medium | Infrastructure | `router.ex` | No health check endpoint | Phase 1 (Claude) |
| CFG-06 | Medium | Infrastructure | `runtime.exs:7-9` | No production connection lifecycle settings | Phase 1 (Claude) |
| CFG-07 | Medium | Infrastructure | `mix.exs`, `application.ex` | No application caching layer | Phase 1 (Codex) |
| CFG-08 | Medium | Infrastructure | `application.ex:32` | Supervisor max_restarts not tuned | Phase 1 (Claude) |
| CFG-09 | Low | Infrastructure | `prod.exs:15` | Deprecated `:warn` log level | Phase 1 (Claude) |
| CFG-10 | Low | Infrastructure | `repo.ex` | Repo module has no optimizations | Phase 1 (Claude) |
| WEB-01 | Medium | Web Config | `endpoint.ex:22` | gzip disabled for static files | Phase 1 (Claude) |
| WEB-02 | Medium | Web Config | (endpoint) | No response compression for API | Phase 1 (Claude) |
| WEB-03 | Medium | Web Config | `prod.exs:12` | cache_static_manifest commented out | Phase 1 (Claude) |
| WEB-04 | Medium | Web Config | (pipeline) | No rate limiting | Phase 1 (Claude) |
| WEB-05 | Low | Web Config | (endpoint) | No ETag / conditional request support | Phase 1 (Claude) |
| WEB-06 | Medium | Web Config | `endpoint.ex:39` | No request body size limit for batch endpoints | Phase 1 (Claude) |
| LV-01 | Medium | LiveView | `import_live/index.ex:110-141` | Full page refresh on every PubSub message | Phase 1 + 2 (Both) |
| LV-02 | Critical | LiveView | `import_live/new.ex:56,79` | Protected import form stuck after cancel | Phase 2 (Codex) |
| LV-03 | Medium | LiveView | `import_live/show.ex` | Error details reparsed every render | Phase 2 (Codex) |
| LV-04 | Medium | LiveView | `import_live/index.ex:82-94` | Crash on malformed import ID | Phase 2 (Codex) |
| LV-05 | Medium | LiveView | `import_live/index.ex:112,136` | Stale pagination after PubSub refresh | Phase 2 (Codex) |
| DEP-01 | Low | Dependencies | `config.exs:34-41` | File-based logger in all environments | Phase 1 (Claude) |
| DEP-02 | Low | Dependencies | `mix.exs:54` | Unmaintained logger_file_backend | Phase 1 (Claude) |
| DEP-03 | Low | Dependencies | `mix.exs:59,63` | Duplicate HTTP client libraries | Phase 1 (Claude) |
| DEP-04 | Low | Dependencies | `mix.exs:55` | Unnecessary `calendar` dependency | Phase 1 (Claude) |
| DEP-05 | Low | Dependencies | `config.exs:81,91` | SSL verification disabled for build tools | Phase 1 (Claude) |
| DEP-06 | Low | Code Quality | `data_import.ex:490-491` | Duplicate regex match then scan | Phase 2 (Claude) |
| DEP-07 | Low | Code Quality | `util.ex:165-170` | Linear scan with String.upcase per validation | Phase 2 (Claude) |
| DEP-08 | Low | Code Quality | `import_live/index.ex`, `show.ex` | Duplicate LiveView helper functions | Phase 2 (Claude) |

**Total findings: 77 open** (11 Critical, 35 High, 22 Medium, 9 Low) — 2 resolved

---

## 14. Priority Action Plan

### P0 -- Fix immediately (security / data corruption / severe performance)

| ID | Issue | Impact | Effort | Found By |
|---|---|---|---|---|
| SEC-04 | Remove `debug_errors: true` in prod | Stack traces leaked to clients | 1 min | Claude |
| SEC-05 | Disable `check_origin: false` in prod | CSRF on LiveView sessions | 5 min | Claude |
| SEC-06 | Add auth to LiveView `/imports` routes | Anyone can create/halt imports | 30 min | Claude |
| NP1-01 | Fix ResourceJSON N+1 (4+ queries/render) | 400+ queries per 100-item list | 2-3 hrs | Both |
| NP1-02 | Move preloads out of JSON serializers | N+1 on 10+ endpoints | 3-4 hrs | Both |
| TXN-01 | Add transactions to enrollment operations | Data corruption on failure | 3-4 hrs | Both |
| TXN-02 | Wrap user/student/teacher creates in Multi | Orphan rows on failure | 2 hrs | Both |
| TXN-03 | Fix resource association updates | Silent data loss + no txn | 2-3 hrs | Both |
| TXN-04 | Fix batch movement return value handling | Success reported on failure | 1-2 hrs | Codex |
| TXN-05 | Wrap enrollment + group_user in transaction | Enrollment without group mapping | 1 hr | Codex |
| TXN-06 | Fix enrollment race condition | Duplicate current enrollments | 1-2 hrs | Codex |
| IDX-01 | Add missing FK indexes (12+ tables) | Full table scans on joins | 1 hr | Both |
| CFG-01 | Fix Oban concurrency vs pool size | Pool exhaustion, API starvation | 5 min | Both |
| IMP-01 | Stream CSV processing (stop Enum.to_list) | Memory spikes on large files | 2-3 hrs | Both |
| IMP-02 | Reduce import halt-check frequency | 5000 extra queries per import | 30 min | Both |
| IMP-03 | Batch import progress updates | 5000 UPDATEs + N*M read amplification | 30 min | Both |

### P1 -- Fix soon (high performance impact, logic bugs)

| ID | Issue | Impact | Effort | Found By |
|---|---|---|---|---|
| SEC-03 | Add allowlists for query param filtering | Arbitrary column access + crashes | 4-5 hrs | Both |
| SEC-08 | Add unique indexes on student_id/apaar_id | Duplicate students under concurrency | 30 min | Codex |
| NP1-04 | Fix group_user_by_type N+1 | 8000 extra queries per 1000-row import | 1 hr | Both |
| NP1-03 | Fix search_problems N+1 (1+2N queries) | Slow problem search | 1-2 hrs | Both |
| NP1-05 | Fix get_tests_containing_problems full scan | O(N) full table scan in Elixir | 2-3 hrs | Both |
| NP1-06 | Fix update_users_for_group N+1 | 1000 queries for 500-user group | 30 min | Both |
| NP1-07 | Fix get_problem over-fetch | Unnecessary data transfer | 30 min | Codex |
| PAG-01 | Add default pagination limits | Full table dumps possible | 2-3 hrs | Both |
| LOOP-01 | Fix update_school_enrollment N+1 | N queries instead of 1 | 30 min | Both |
| LOOP-02 | Batch insert_resource_concepts | N inserts instead of 1 | 30 min | Claude |
| LOOP-04 | Make batch_process async (Oban) | Request timeouts on large batches | 3-4 hrs | Both |
| LOOP-05 | Fix student ID generation retry loop | Up to 1000 DB queries | 1-2 hrs | Claude |
| IDX-02 | Add composite enrollment indexes | Slow enrollment queries | 30 min | Both |
| IDX-03 | Add uniqueness constraints on join tables | Duplicate rows possible | 30 min | Codex |
| IMP-07 | Cache static lookups during import | 1000x repeated queries | 1-2 hrs | Both |
| IMP-08 | Guard worker against halted/missing file | Worker crash on halted import | 30 min | Codex |
| IMP-09 | Handle failed Oban enqueue | Import stuck in "pending" forever | 30 min | Codex |
| BUG-01 | Fix add_error DateTime/atom bug | Validation errors silently wrong | 15 min | Both |
| BUG-02 | Fix validators that raise vs add_error | CSV import process crashes | 30 min | Claude |
| BUG-03 | Fix String.to_atom atom table leak | VM crash on atom exhaustion | 15 min | Claude |
| BUG-04 | Fix enrollment ID domain mismatch | Wrong enrollment validation | 1 hr | Codex |
| BUG-05 | Fix future date validation timezone bug | Allows 5h30m future timestamps | 30 min | Codex |
| BUG-06 | Fix test problem ordering | Problems returned in wrong order | 30 min | Codex |
| TXN-07 | Add locking to batch movement | Race condition / data corruption | 2-3 hrs | Claude |

### P2 -- Plan for (moderate impact, larger effort or lower risk)

| ID | Issue | Impact | Effort | Found By |
|---|---|---|---|---|
| IMP-04 | Combine CSV counting and parsing | Double I/O and CPU cost | 1-2 hrs | Claude |
| IMP-05 | Stream CSV validation (first line only) | Memory waste on validation | 30 min | Claude |
| IMP-06 | Cancel non-transient Oban failures | Unnecessary retries of bad data | 30 min | Claude |
| LOOP-08 | Move import download to Oban worker | Blocking HTTP request | 2-3 hrs | Codex |
| CFG-02 | Fix query timeout (120s -> 15-30s) | Masked performance issues | 15 min | Both |
| CFG-03 | Fix queue_target/queue_interval | Hidden pool saturation | 15 min | Both |
| CFG-04 | Add Oban Lifeline plugin | Stuck jobs after deploys | 15 min | Claude |
| CFG-07 | Add ETS cache for lookup tables | Repeated queries for static data | 2-3 hrs | Codex |
| IDX-04 | Add JSONB/text search indexes | Sequential scans on search | 1-2 hrs | Codex |
| WEB-01/02/03 | Enable gzip, compression, caching | Bandwidth waste | 1 hr | Claude |
| WEB-04 | Add rate limiting | DoS vulnerability | 2-3 hrs | Claude |
| WEB-06 | Add body size limits for batch endpoints | Memory/resource abuse | 30 min | Claude |
| BUG-07 | Fix IST/UTC timezone storage | Wrong timestamps in DB | 2-3 hrs | Claude |
| BUG-08 | Add error clause in process_with_batch_info | CaseClauseError at runtime | 15 min | Claude |
| BUG-09 | Guard against nil status info | MatchError crash | 15 min | Claude |
| BUG-10 | Narrow rescue clause in re-enrollment | Swallowed critical exceptions | 15 min | Claude |
| BUG-11 | Fix start_row parsing | ArgumentError on bad input | 15 min | Codex |
| LV-01 | Debounce/scope PubSub refresh | Excessive DB load from LiveView | 1-2 hrs | Both |
| LV-02 | Fix stuck protected import form | UI stuck state | 30 min | Codex |
| LV-03 | Cache parsed error details | Repeated JSON parsing | 30 min | Codex |
| LV-04 | Guard stop modal against bad IDs | Crash on malformed input | 15 min | Codex |
| LV-05 | Fix stale pagination state | Wrong page counts | 30 min | Codex |
| LOOP-07 | Eliminate redundant group fetches | Wasted queries (2-6x) | 1 hr | Claude |
| LOOP-09 | Fix O(N^2) list concatenation | Slow import processing | 15 min | Claude |
| IMP-10 | Consolidate error handling + cap errors | Duplicate writes + unbounded array | 1 hr | Claude |
| IMP-11 | Pass count instead of length(records) | O(N) waste | 15 min | Both |
| CFG-05 | Add health check endpoint | No LB/orchestrator health checks | 30 min | Claude |
| CFG-06 | Add connection lifecycle settings | Stale connections in cloud | 15 min | Claude |
| CFG-08 | Tune supervisor max_restarts | Entire app crashes on Goth failure | 15 min | Claude |

### P3 -- Low priority (minor impact)

| ID | Issue | Impact | Effort | Found By |
|---|---|---|---|---|
| IDX-05 | Add session/imports indexes | Slow dashboard/search | 30 min | Codex |
| LOOP-03 | Batch move_resources | Individual updates | 30 min | Claude |
| LOOP-06 | Batch update_current_status | Individual updates | 30 min | Claude |
| IMP-12 | Fix naive \\n split in fallback counting | Wrong counts for multiline CSV | 30 min | Claude |
| BUG-12 | Improve dropout error messages | No diagnostic value | 15 min | Claude |
| CFG-09 | Fix deprecated `:warn` log level | Deprecation warning | 1 min | Claude |
| CFG-10 | Add Repo optimizations for PgBouncer | Needed if using connection pooler | 15 min | Claude |
| DEP-01 | Move file logger to dev only | Unbounded log file in prod | 15 min | Claude |
| DEP-02 | Replace unmaintained logger_file_backend | Compatibility issues | 30 min | Claude |
| DEP-03 | Remove duplicate HTTP client deps | Extra compile time/memory | 5 min | Claude |
| DEP-04 | Remove unnecessary `calendar` dep | Dead dependency | 5 min | Claude |
| DEP-05 | Fix SSL verification for build tools | MITM risk for build tools | 15 min | Claude |
| DEP-06 | Fix duplicate regex operation | Minor CPU waste | 5 min | Claude |
| DEP-07 | Use compile-time MapSet for validation | Minor CPU waste | 15 min | Claude |
| DEP-08 | Extract shared LiveView helpers | Code duplication | 30 min | Claude |
| WEB-05 | Add ETag support | Bandwidth waste on stable data | 2-3 hrs | Claude |

---

*This document is the authoritative, consolidated codebase review combining Phase 1 (broad sweep) and Phase 2 (deep dive). All findings from both phases are preserved. Where both phases identified the same issue, findings were merged with combined file references and the more detailed description retained. Severity follows Phase 2 where conflicts existed.*

---

## 15. Resolved

| ID | Severity | Issue | Resolution | GitHub Issue | Status |
|----|----------|-------|------------|--------------|--------|
| SEC-01 | Critical | Authentication middleware was commented out — all API endpoints publicly accessible | Authentication middleware re-enabled in `endpoint.ex:48`. Bearer token auth now enforced on all `/api` routes. | [#459](https://github.com/avantifellows/db-service/issues/459) | Closed |
| SEC-02 | Critical | Auth bypass via Referer header — setting `Referer: swagger` skipped authentication | Middleware rewritten to use path-prefix matching (`String.starts_with?` on `/api`). All Referer-based bypasses removed. | No issue was created | Fixed |
