defmodule Dbservice.Repo.Migrations.AddGroupUserCompositeIndex do
  use Ecto.Migration

  # CONCURRENTLY can't run inside a transaction, so disable the DDL transaction.
  # The migration lock is intentionally kept (not disabled): the repo is configured
  # with migration_lock: :pg_advisory_lock (config/config.exs), which holds the lock
  # via an advisory lock that doesn't block the concurrent build.
  @disable_ddl_transaction true

  # The membership probe `WHERE group_id = ? AND user_id = ?` is the #1 cumulative time
  # consumer. With only separate single-column indexes, the planner picks one and filters on
  # the other - scanning many rows for large groups (some have 100k+ members). A composite
  # with user_id leading (users have ~9-12 memberships, far more selective than group_id)
  # answers the probe in one traversal and also serves user_id-only lookups.
  #
  # Non-unique on purpose: a UNIQUE index would need existing duplicate (user_id, group_id)
  # pairs de-duped first, which is tracked separately.
  #
  # Uses `create` (not `create_if_not_exists`): an interrupted concurrent build leaves an
  # INVALID index, which `create_if_not_exists` would silently skip on retry (name-only
  # check). `create` surfaces it so it can be dropped and rebuilt. Check pg_index.indisvalid
  # after deploy.
  def change do
    create index(:group_user, [:user_id, :group_id], concurrently: true)
  end
end
