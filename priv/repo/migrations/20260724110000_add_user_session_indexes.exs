# 20260701120000 is already deployed as AddLmsStudentIngestion.
defmodule Dbservice.Repo.Migrations.AddUserSessionIndexes do
  use Ecto.Migration

  # CREATE INDEX CONCURRENTLY cannot run inside a transaction, and the migration
  # advisory lock can conflict with the concurrent build, so both are disabled.
  @disable_ddl_transaction true
  @disable_migration_lock true

  # `user_session` is the largest table (~3.9M rows) and was left without indexes on
  # `user_id`/`session_id` after `user_id` was dropped and re-added via references/2
  # (which creates the FK but not an index). Both columns are queried on hot paths
  # (deletes, exists? checks, association preloads), causing full table scans.
  def change do
    create_if_not_exists index(:user_session, [:user_id], concurrently: true)
    create_if_not_exists index(:user_session, [:session_id], concurrently: true)
  end
end
