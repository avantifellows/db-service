defmodule Dbservice.Repo.Migrations.DedupBatchGroupUsers do
  @moduledoc """
  ISSUE 2 remediation. Students can have a single current batch in
  `enrollment_record` but multiple batch rows in `group_user` (root cause:
  `BatchEnrollmentService.update_batch_user/3` used to repoint only the first
  matching row and never delete the rest). Duplicate batch memberships then made
  grade/stream edits fail in `LmsStudentUpdate` (`:multiple_group_users`).

  Keep rule (ER-anchored — the enrollment_record is the source of truth, because
  `inserted_at` on group_user is unreliable after in-place repointing):

    * Keep batch group_user rows whose `group.child_id` is one of the user's
      CURRENT batch-ER `group_id`s.
    * Delete batch group_user rows that match no current batch ER (orphans).
    * For exact duplicates on the same current batch, keep the latest
      `inserted_at` (tie-break max id).
    * If any current-ER batch is absent from the user's batch group_user rows,
      skip the WHOLE user for manual review (RAISE NOTICE) — we never risk
      stripping a live membership.

  Safe for legitimately multi-batch students: every current batch is kept.

  Reversible: deleted rows are snapshotted into a `bak_*` table that `down/0`
  re-inserts and then drops.
  """
  use Ecto.Migration

  def up do
    # Keepers = one row per current batch (latest inserted_at, max id tie-break)
    # for users NOT in manual review. Deletable = every other batch group_user of
    # those users (orphans + extra dups). Window function + anti-joins, single pass.
    execute("""
    CREATE TABLE bak_20260725120001_group_user AS
    WITH batch_gu AS (
      SELECT gu.id AS gu_id, gu.user_id, gu.inserted_at, g.child_id AS batch_id
      FROM group_user gu
      JOIN "group" g ON g.id = gu.group_id AND g.type = 'batch'
    ),
    current_batch_er AS (
      SELECT DISTINCT er.user_id, er.group_id AS batch_id
      FROM enrollment_record er
      WHERE er.group_type = 'batch' AND er.is_current = true
    ),
    manual_review_users AS (
      SELECT DISTINCT cbe.user_id
      FROM current_batch_er cbe
      LEFT JOIN batch_gu bg
        ON bg.user_id = cbe.user_id AND bg.batch_id = cbe.batch_id
      WHERE bg.gu_id IS NULL
    ),
    keepers AS (
      SELECT gu_id FROM (
        SELECT bg.gu_id,
               ROW_NUMBER() OVER (
                 PARTITION BY bg.user_id, bg.batch_id
                 ORDER BY bg.inserted_at DESC, bg.gu_id DESC
               ) AS rn
        FROM batch_gu bg
        JOIN current_batch_er cbe
          ON cbe.user_id = bg.user_id AND cbe.batch_id = bg.batch_id
        LEFT JOIN manual_review_users mru ON mru.user_id = bg.user_id
        WHERE mru.user_id IS NULL
      ) r
      WHERE r.rn = 1
    )
    SELECT gu.*
    FROM group_user gu
    JOIN batch_gu bg ON bg.gu_id = gu.id
    LEFT JOIN manual_review_users mru ON mru.user_id = bg.user_id
    LEFT JOIN keepers k ON k.gu_id = gu.id
    WHERE mru.user_id IS NULL
      AND k.gu_id IS NULL;
    """)

    execute("""
    DELETE FROM group_user gu
    USING bak_20260725120001_group_user b
    WHERE gu.id = b.id;
    """)

    execute("""
    DO $$
    DECLARE n integer;
    BEGIN
      SELECT count(*) INTO n FROM (
        SELECT DISTINCT cbe.user_id
        FROM enrollment_record cbe
        LEFT JOIN "group" g
          ON g.type = 'batch' AND g.child_id = cbe.group_id
        LEFT JOIN group_user gu
          ON gu.group_id = g.id AND gu.user_id = cbe.user_id
        WHERE cbe.group_type = 'batch' AND cbe.is_current = true
          AND gu.id IS NULL
      ) s;
      RAISE NOTICE 'ISSUE-2: % users skipped for manual review (current batch ER with no group_user)', n;
    END $$;
    """)
  end

  def down do
    execute("""
    INSERT INTO group_user (id, group_id, user_id, inserted_at, updated_at)
    SELECT id, group_id, user_id, inserted_at, updated_at
    FROM bak_20260725120001_group_user;
    """)

    execute("DROP TABLE IF EXISTS bak_20260725120001_group_user;")
  end
end
