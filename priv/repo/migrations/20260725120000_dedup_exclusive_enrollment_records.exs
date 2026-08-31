defmodule Dbservice.Repo.Migrations.DedupExclusiveEnrollmentRecords do
  @moduledoc """
  ISSUE 1 remediation. Some users hold more than one `is_current = true`
  `enrollment_record` for an exclusive `group_type` (`auth_group`, `school`,
  `grade`). App code treats these as exclusive (`EnrollmentService`
  `@exclusive_group_types` / `validate_no_existing_enrollment/3`) but nothing
  enforced it at the DB level. This migration collapses the duplicates:

    (2a) Keep the current ER with the newest `start_date`
         (tie-break: newest `inserted_at`, then max `id`); mark the rest
         `is_current = false` and stamp `end_date` (mirrors how the app
         supersedes an enrollment).
    (2b) Mirror the result into `group_user`: keep only the group_user rows that
         match the surviving current ER child (per exclusive type); delete stale
         and exact-duplicate rows. Users whose surviving current ER has no
         matching group_user are skipped for manual review (RAISE NOTICE).

  Reversible: the rows changed/deleted are snapshotted into `bak_*` tables that
  `down/0` restores from and then drops. The backup tables persist after `up/0`
  as the safety net for this destructive repair.
  """
  use Ecto.Migration

  def up do
    # --- Snapshot the ER rows we are about to flip (the "losers") -------------
    execute("""
    CREATE TABLE bak_20260725120000_er AS
    SELECT er.id, er.is_current, er.end_date, er.updated_at
    FROM enrollment_record er
    JOIN (
      SELECT id FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                 PARTITION BY user_id, group_type
                 ORDER BY start_date DESC NULLS LAST, inserted_at DESC, id DESC
               ) AS rn
        FROM enrollment_record
        WHERE is_current = true
          AND group_type IN ('auth_group','school','grade')
      ) ranked
      WHERE ranked.rn > 1
    ) losers ON losers.id = er.id;
    """)

    # --- (2a) Flip surplus current exclusive ER rows --------------------------
    execute("""
    WITH ranked AS (
      SELECT id, user_id, group_type, start_date,
             ROW_NUMBER() OVER (
               PARTITION BY user_id, group_type
               ORDER BY start_date DESC NULLS LAST, inserted_at DESC, id DESC
             ) AS rn
      FROM enrollment_record
      WHERE is_current = true
        AND group_type IN ('auth_group','school','grade')
    ),
    winners AS (SELECT user_id, group_type, start_date FROM ranked WHERE rn = 1),
    losers  AS (SELECT id, user_id, group_type FROM ranked WHERE rn > 1)
    UPDATE enrollment_record er
    SET is_current = false,
        end_date   = GREATEST(er.start_date, w.start_date),
        updated_at = NOW()
    FROM losers l
    JOIN winners w ON w.user_id = l.user_id AND w.group_type = l.group_type
    WHERE er.id = l.id;
    """)

    # --- Snapshot the group_user rows we are about to delete ------------------
    # For each (user, exclusive type) that HAS a current ER with a matching
    # group_user (i.e. not manual-review, and in scope), keep exactly one row —
    # the one matching the surviving current ER child, latest inserted_at (max id
    # tie-break) — and delete the rest (stale-child rows and exact duplicates).
    # (user,type) pairs with no current ER, or whose current child has no matching
    # group_user, are left entirely untouched. Uses window functions + anti-join
    # instead of correlated subqueries so it runs in a single pass.
    execute("""
    CREATE TABLE bak_20260725120000_group_user AS
    WITH exclusive_gu AS (
      SELECT gu.id AS gu_id, gu.user_id, gu.inserted_at,
             g.type AS group_type, g.child_id
      FROM group_user gu
      JOIN "group" g ON g.id = gu.group_id
                    AND g.type IN ('auth_group','school','grade')
    ),
    current_er AS (
      SELECT er.user_id, er.group_type, er.group_id AS child_id
      FROM enrollment_record er
      WHERE er.is_current = true
        AND er.group_type IN ('auth_group','school','grade')
    ),
    -- (user,type) whose surviving current ER child is present in group_user.
    -- Post-2a there is exactly one current child per (user,type).
    prunable AS (
      SELECT DISTINCT ce.user_id, ce.group_type, ce.child_id
      FROM current_er ce
      JOIN exclusive_gu eg
        ON eg.user_id = ce.user_id
       AND eg.group_type = ce.group_type
       AND eg.child_id = ce.child_id
    ),
    ranked AS (
      SELECT eg.gu_id,
             ROW_NUMBER() OVER (
               PARTITION BY eg.user_id, eg.group_type
               ORDER BY (eg.child_id = p.child_id) DESC,
                        eg.inserted_at DESC,
                        eg.gu_id DESC
             ) AS rn
      FROM exclusive_gu eg
      JOIN prunable p
        ON p.user_id = eg.user_id AND p.group_type = eg.group_type
    )
    SELECT gu.*
    FROM group_user gu
    JOIN ranked r ON r.gu_id = gu.id
    WHERE r.rn > 1;
    """)

    # --- (2b) Delete those group_user rows ------------------------------------
    execute("""
    DELETE FROM group_user gu
    USING bak_20260725120000_group_user b
    WHERE gu.id = b.id;
    """)

    # --- Report the manual-review population ----------------------------------
    execute("""
    DO $$
    DECLARE n integer;
    BEGIN
      SELECT count(*) INTO n FROM (
        SELECT DISTINCT ce.user_id, ce.group_type
        FROM enrollment_record ce
        LEFT JOIN "group" g
          ON g.type = ce.group_type AND g.child_id = ce.group_id
        LEFT JOIN group_user gu
          ON gu.group_id = g.id AND gu.user_id = ce.user_id
        WHERE ce.is_current = true
          AND ce.group_type IN ('auth_group','school','grade')
          AND gu.id IS NULL
      ) s;
      RAISE NOTICE 'ISSUE-1: % (user,type) pairs skipped for manual review (current ER with no matching group_user)', n;
    END $$;
    """)
  end

  def down do
    execute("""
    UPDATE enrollment_record er
    SET is_current = b.is_current,
        end_date   = b.end_date,
        updated_at = b.updated_at
    FROM bak_20260725120000_er b
    WHERE er.id = b.id;
    """)

    execute("""
    INSERT INTO group_user (id, group_id, user_id, inserted_at, updated_at)
    SELECT id, group_id, user_id, inserted_at, updated_at
    FROM bak_20260725120000_group_user;
    """)

    execute("DROP TABLE IF EXISTS bak_20260725120000_group_user;")
    execute("DROP TABLE IF EXISTS bak_20260725120000_er;")
  end
end
