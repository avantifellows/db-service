# LMS Curriculum Schema and Chapter Exam Config Loader

This adds the db-service side for af_lms issue #88.

## Tables

- `lms_chapter_exam_configs`: one row per `chapter_id + exam_track`, with syllabus inclusion, prescribed minutes, coverage sequence, audit emails, and timestamps.
- `lms_curriculum_logs`: teacher session logs scoped by `school_code + program_id + grade_id + subject_id + exam_track`, with duration, log date, audit emails, soft delete, and timestamps.
- `lms_curriculum_log_topics`: topics covered in a curriculum log, unique per `curriculum_log_id + topic_id`.
- `lms_curriculum_chapter_completions`: durable chapter completion state scoped by `school_code + program_id + chapter_id + exam_track`, with active uniqueness where `deleted_at IS NULL`.

`school_code` is intentionally not an FK because the current `school.code` column is indexed but not unique. The tables still store `school_code` because that is the LMS-facing school identifier.

## Loader

The loader embeds the 2026-27 timemap data directly in code. Source CSVs used to build the embedded dataset:

- `Intervention Timemap 2026-27 - Physics.csv`
- `Intervention Timemap 2026-27 - Chemsitry.csv`
- `Intervention Timemap 2026-27 - Mathematics.csv`
- `Intervention Timemap 2026-27 - Biology.csv`

Expected embedded counts:

- Physics: 87
- Chemistry: 96
- Maths: 56
- Biology: 38
- Total: 277

Mathematics is normalized to canonical subject name `Maths`. Biology is included, so the target database must already have the Biology chapters loaded in `chapter` before running this loader.

The loader resolves `chapter_code` to `chapter.id`, upserts by `chapter_id + exam_track`, and runs all rows in one transaction. It aborts and rolls back on missing or duplicate chapter codes. Name mismatches are reported as warnings and do not block the load; issue #73 remains the review path for deciding those mismatch fixes.

## Commands

Local:

```bash
mix ecto.migrate
mix lms.load_chapter_exam_configs --email your.email@avantifellows.org
```

Staging:

```bash
MIX_ENV=prod mix ecto.migrate
MIX_ENV=prod mix lms.load_chapter_exam_configs --email your.email@avantifellows.org
```

Production:

```bash
MIX_ENV=prod mix ecto.migrate
MIX_ENV=prod mix lms.load_chapter_exam_configs --email your.email@avantifellows.org
```

Only run staging or production commands from the normal db-service deployment/runbook environment with the intended database credentials. Do not run them from a local shell unless that is the approved deploy process.

## Verification

After loading, verify the count:

```sql
SELECT count(*) FROM lms_chapter_exam_configs;
```

Expected: `277`

Verify by track:

```sql
SELECT exam_track, count(*)
FROM lms_chapter_exam_configs
GROUP BY exam_track
ORDER BY exam_track;
```

Verify out-of-syllabus minutes:

```sql
SELECT count(*)
FROM lms_chapter_exam_configs
WHERE is_in_syllabus = false
  AND prescribed_minutes <> 0;
```

Expected: `0`

Keep the loader output warnings with the rollout notes so chapter name mismatches can be reconciled through issue #73.
