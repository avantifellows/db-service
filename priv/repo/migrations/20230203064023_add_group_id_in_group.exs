defmodule Dbservice.Repo.Migrations.AddGroupIdInGroup do
  use Ecto.Migration

  def change do
    alter table(:group) do
      add :group_id, :string
    end
  end
end
