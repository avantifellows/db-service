defmodule Dbservice.Repo.Migrations.ModifySessionTable do
  use Ecto.Migration

  def change do
    alter table("session") do
      add :is_active, :boolean, default: true, null: false
      add :session_uuid, :string
    end
  end
end
