defmodule Dbservice.Repo.Migrations.AddSessionOccurrenceCompositeIndex do
  use Ecto.Migration

  # CONCURRENTLY cannot run inside a transaction, so disable the DDL transaction.
  # The migration lock is intentionally NOT disabled: with the repo configured to
  # use :pg_advisory_lock (see config/config.exs), Ecto can hold the migration
  # lock via an advisory lock that does not block the concurrent index build.
  @disable_ddl_transaction true

  # The active-window query `WHERE session_id = ? AND start_time <= ? AND end_time >= ?`
  # currently relies on a BitmapAnd of separate single-column indexes (the #1/#3 cumulative
  # time consumers). A composite (session_id, start_time, end_time) lets the planner satisfy
  # the whole predicate in one B-tree traversal: equality on session_id, then a range scan.
  #
  # Uses `create` (not `create_if_not_exists`): if a concurrent build is interrupted it
  # leaves an INVALID index behind, and `create_if_not_exists` only checks the name — it
  # would skip the invalid index and report success. `create` surfaces the failure so the
  # invalid index can be dropped and rebuilt. Verify with `pg_index.indisvalid` after deploy.
  def change do
    create index(:session_occurrence, [:session_id, :start_time, :end_time], concurrently: true)
  end
end
