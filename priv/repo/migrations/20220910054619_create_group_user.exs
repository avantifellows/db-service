defmodule Dbservice.Repo.Migrations.CreateGroupUser do
  use Ecto.Migration

  def change do
    create table(:group_user) do
      add :group_id, references(:group, on_delete: :nothing)
      add :user_id, references(:user, on_delete: :nothing)

      timestamps()
    end
  end
end
