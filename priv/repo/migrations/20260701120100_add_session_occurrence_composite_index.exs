defmodule Dbservice.Repo.Migrations.AddSessionOccurrenceCompositeIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # The active-window query `WHERE session_id = ? AND start_time <= ? AND end_time >= ?`
  # currently relies on a BitmapAnd of separate single-column indexes (the #1/#3 cumulative
  # time consumers). A composite (session_id, start_time, end_time) lets the planner satisfy
  # the whole predicate in one B-tree traversal: equality on session_id, then a range scan.
  def change do
    create_if_not_exists index(:session_occurrence, [:session_id, :start_time, :end_time],
                           concurrently: true
                         )
  end
end
