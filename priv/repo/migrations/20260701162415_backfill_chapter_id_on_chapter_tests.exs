defmodule Dbservice.Repo.Migrations.BackfillChapterIdOnChapterTests do
  use Ecto.Migration

  # Seed type_params.chapter_id on existing chapter_test resources by deriving the chapter
  # from the test's problems (test -> problems -> resource_chapter -> chapter). This mirrors
  # how a chapter test's chapter has always been implicit (a question can only be authored
  # inside a chapter/topic). Only tests whose problems resolve to exactly ONE chapter are
  # backfilled; orphan/hand-made tests are left unset. Validated on staging: 107/111
  # chapter tests resolve to a single chapter, 0 to multiple, 4 to none.
  #
  # chapter_id lives in the type_params jsonb (not a shared resource column) because it is
  # only meaningful for chapter_test, one of several test subtypes.

  def up do
    execute("""
    UPDATE resource t
    SET type_params = jsonb_set(t.type_params, '{chapter_id}', to_jsonb(sub.chapter_id))
    FROM (
      SELECT tp.test_id, min(rc.chapter_id) AS chapter_id
      FROM (
        SELECT r.id AS test_id, (prob->>'id')::bigint AS problem_id
        FROM resource r,
             jsonb_array_elements(r.type_params->'subjects') subj,
             jsonb_array_elements(subj->'sections') sec,
             jsonb_array_elements(
               COALESCE(sec->'compulsory'->'problems', '[]'::jsonb)
               || COALESCE(sec->'optional'->'problems', '[]'::jsonb)
             ) prob
        WHERE r.type = 'test' AND r.subtype = 'chapter_test'
      ) tp
      JOIN resource_chapter rc ON rc.resource_id = tp.problem_id
      GROUP BY tp.test_id
      HAVING count(DISTINCT rc.chapter_id) = 1
    ) sub
    WHERE t.id = sub.test_id
      AND t.type = 'test'
      AND t.subtype = 'chapter_test'
    """)
  end

  def down do
    execute("""
    UPDATE resource
    SET type_params = type_params - 'chapter_id'
    WHERE type = 'test'
      AND subtype = 'chapter_test'
      AND type_params ? 'chapter_id'
    """)
  end
end
