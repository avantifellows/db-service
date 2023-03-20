defmodule Dbservice.Repo.Migrations.ModifyGroupIdInGroupUser do
  use Ecto.Migration

  def change do
    alter table(:group_user) do
      remove :group_id
      add :group_id, references(:group_type, on_delete: :nothing)
    end
  end
end
