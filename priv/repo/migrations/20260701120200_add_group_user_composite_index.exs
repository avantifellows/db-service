defmodule Dbservice.Repo.Migrations.AddGroupUserCompositeIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # The membership probe `WHERE group_id = ? AND user_id = ?` is the #1 cumulative time
  # consumer. With only separate single-column indexes, the planner picks one and filters on
  # the other - scanning many rows for large groups (some have 100k+ members). A composite
  # with user_id leading (users have ~9-12 memberships, far more selective than group_id)
  # answers the probe in one traversal and also serves user_id-only lookups.
  #
  # Non-unique on purpose: a UNIQUE index would need existing duplicate (user_id, group_id)
  # pairs de-duped first, which is tracked separately.
  def change do
    create_if_not_exists index(:group_user, [:user_id, :group_id], concurrently: true)
  end
end
