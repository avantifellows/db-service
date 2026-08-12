defmodule Dbservice.Repo.Migrations.CleanupEnrollmentRecords do
  use Ecto.Migration

  # Runs inside a transaction (default) so a bad predicate rolls back cleanly.

  # ===========================================================================
  # TODO(user): SET THE PREDICATE BELOW BEFORE RUNNING.
  #
  # Replace @wrong_rows_predicate with the EXACT SQL condition identifying the
  # wrong `enrollment_record` rows to delete (the stray 2025-2026 rows Priyanka
  # flagged). It is spliced verbatim into `WHERE <predicate>` against the
  # `enrollment_record` table.
  #
  # It DEFAULTS TO "false" so, until you fill it in, this migration is a safe
  # no-op (matches zero rows, deletes nothing) and won't affect CI / test DBs.
  #
  # Illustrative example ONLY — confirm the real criteria before using:
  #   "is_current = true AND group_type = 'school' AND academic_year = '2025-2026'"
  # ===========================================================================
  @wrong_rows_predicate "false"

  # Deleted rows are snapshotted here first so `down/0` can restore them. Left in
  # place after `up/0` as a safety net; drop it manually once the cleanup is
  # verified in production.
  @backup_table "enrollment_record_cleanup_backup_20260729"

  def up do
    # 1. Snapshot the rows we're about to delete.
    execute("""
    CREATE TABLE #{@backup_table} AS
    SELECT * FROM enrollment_record WHERE #{@wrong_rows_predicate}
    """)

    # 2. Loud sanity log of how many rows matched.
    execute("""
    DO $$
    DECLARE cnt integer;
    BEGIN
      SELECT COUNT(*) INTO cnt FROM #{@backup_table};
      RAISE NOTICE 'cleanup_enrollment_records: % row(s) matched and will be deleted', cnt;
      -- TODO(user): optional sanity cap once the predicate is known, e.g.
      -- IF cnt > 1000 THEN
      --   RAISE EXCEPTION 'refusing to delete % rows (predicate too broad)', cnt;
      -- END IF;
    END $$;
    """)

    # 3. Delete the wrong rows.
    execute("DELETE FROM enrollment_record WHERE #{@wrong_rows_predicate}")
  end

  def down do
    # Restore the deleted rows from the backup, then drop the backup table.
    execute("INSERT INTO enrollment_record SELECT * FROM #{@backup_table}")
    execute("DROP TABLE #{@backup_table}")
  end
end
