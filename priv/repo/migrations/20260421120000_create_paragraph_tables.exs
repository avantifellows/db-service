defmodule Dbservice.Repo.Migrations.CreateParagraphTables do
  use Ecto.Migration

  def change do
    create table(:paragraph) do
      add :body, :jsonb, null: false
      timestamps()
    end
  end
end
