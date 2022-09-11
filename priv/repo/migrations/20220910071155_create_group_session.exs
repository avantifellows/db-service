defmodule Dbservice.Repo.Migrations.CreateGroupSession do
  use Ecto.Migration

  def change do
    create table(:group_session) do
      add :group_id, references(:group, on_delete: :nothing)
      add :session_id, references(:session, on_delete: :nothing)

      timestamps()
    end

  end
end
