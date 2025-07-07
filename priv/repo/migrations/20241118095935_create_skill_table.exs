defmodule Dbservice.Repo.Migrations.CreateSkillTable do
  use Ecto.Migration

  def change do
    create table(:skill) do
      add :name, :string, null: false

      timestamps()
    end
  end
end
