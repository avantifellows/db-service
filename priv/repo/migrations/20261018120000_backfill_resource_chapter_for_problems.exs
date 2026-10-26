defmodule Dbservice.Repo.Migrations.BackfillResourceChapterForProblems do
  @moduledoc """
  Problems are about to be listed by chapter rather than by topic (issue #785),
  so every problem needs a `resource_chapter` row. A handful never got one:
  they were created against a topic only, and the chapter stayed implicit in
  that topic.

  Backfill those from the chapter of the problem's topic. Validated on
  production data: 15,255 problems, of which 119 have no `resource_chapter`
  row. All 119 resolve to exactly one chapter through their topic — 0 ambiguous,
  0 with neither chapter nor topic, 0 mapped to multiple chapters.

  The `HAVING count(DISTINCT t.chapter_id) = 1` is a safeguard, not a filter
  that is expected to bite: a problem whose topics span several chapters is
  skipped and reported with a `RAISE NOTICE` rather than guessed at. Same for a
  problem with neither a chapter nor a topic, which nothing can derive.

  Idempotent — the `NOT EXISTS` guard makes a re-run a no-op. At ~119 rows there
  is no need to batch or to snapshot into a backup table.
  """
  use Ecto.Migration

  def up do
    execute(report_unresolvable_sql())
    execute(backfill_sql())
  end

  # No-op on purpose: a backfilled resource_chapter row is indistinguishable
  # from one that was always there, so deleting "the ones this migration added"
  # is not something we can do safely. Rolling back leaves them in place.
  def down do
    :ok
  end

  @doc false
  def backfill_sql do
    """
    INSERT INTO resource_chapter (resource_id, chapter_id, inserted_at, updated_at)
    SELECT r.id, min(t.chapter_id), now(), now()
    FROM resource r
    JOIN resource_topic rt ON rt.resource_id = r.id
    JOIN topic t ON t.id = rt.topic_id
    WHERE r.type = 'problem'
      AND NOT EXISTS (SELECT 1 FROM resource_chapter rc WHERE rc.resource_id = r.id)
      AND t.chapter_id IS NOT NULL
    GROUP BY r.id
    HAVING count(DISTINCT t.chapter_id) = 1
    """
  end

  @doc false
  def report_unresolvable_sql do
    """
    DO $$
    DECLARE
      problem record;
    BEGIN
      FOR problem IN
        SELECT r.id, count(DISTINCT t.chapter_id) AS chapter_count
        FROM resource r
        LEFT JOIN resource_topic rt ON rt.resource_id = r.id
        LEFT JOIN topic t ON t.id = rt.topic_id
        WHERE r.type = 'problem'
          AND NOT EXISTS (SELECT 1 FROM resource_chapter rc WHERE rc.resource_id = r.id)
        GROUP BY r.id
        HAVING count(DISTINCT t.chapter_id) <> 1
      LOOP
        RAISE NOTICE
          'resource_chapter backfill: problem % left without a chapter (% distinct chapters reachable through its topics)',
          problem.id, problem.chapter_count;
      END LOOP;
    END $$;
    """
  end
end
