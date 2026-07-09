defmodule Dbservice.Repo.Migrations.AddSessionOccurrenceEndTimeIdIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Backs the active-window ordering `ORDER BY end_time, id`: the existing single-column
  # end_time index already serves the temporal filter, but a composite (end_time, id) lets
  # PostgreSQL satisfy the filter and the id tie-breaker in one B-tree traversal (and
  # supports future keyset/cursor pagination on that same key).
  def change do
    create_if_not_exists index(:session_occurrence, [:end_time, :id], concurrently: true)
  end
end
