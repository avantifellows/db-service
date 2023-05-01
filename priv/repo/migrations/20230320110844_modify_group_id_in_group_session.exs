defmodule Dbservice.Repo.Migrations.ModifyGroupIdInGroupSession do
  use Ecto.Migration

  def change do
    alter table(:group_session) do
      remove :group_id
      add :group_type_id, references(:group_type, on_delete: :nothing)
    end
  end
end
