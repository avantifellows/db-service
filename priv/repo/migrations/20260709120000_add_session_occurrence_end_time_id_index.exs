defmodule Dbservice.Repo.Migrations.AddSessionOccurrenceEndTimeIdIndex do
  use Ecto.Migration

  # CONCURRENTLY can't run inside a transaction, so disable the DDL transaction.
  # The migration lock is intentionally kept (not disabled): the repo is configured
  # with migration_lock: :pg_advisory_lock (config/config.exs), which holds the lock
  # via an advisory lock that doesn't block the concurrent build.
  @disable_ddl_transaction true

  # Backs the active-window ordering `ORDER BY end_time, id`: the existing single-column
  # end_time index already serves the temporal filter, but a composite (end_time, id) lets
  # PostgreSQL satisfy the filter and the id tie-breaker in one B-tree traversal (and
  # supports future keyset/cursor pagination on that same key).
  #
  # Uses `create` (not `create_if_not_exists`): an interrupted concurrent build leaves an
  # INVALID index, which `create_if_not_exists` would silently skip on retry (name-only
  # check). `create` surfaces it so it can be dropped and rebuilt. Check pg_index.indisvalid
  # after deploy.
  def change do
    create index(:session_occurrence, [:end_time, :id], concurrently: true)
  end
end
