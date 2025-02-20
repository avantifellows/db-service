defmodule Dbservice.Repo.Migrations.CreateLanguageTable do
  use Ecto.Migration

  def change do
    create table(:language) do
      add :name, :string, null: false

      timestamps()
    end
  end
end
