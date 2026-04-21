defmodule Dbservice.Repo.Migrations.CreateParagraphTables do
  use Ecto.Migration

  def change do
    create table(:paragraph) do
      add :body, :jsonb, null: false
      add :lang_id, references(:language, on_delete: :nothing), null: false
      timestamps()
    end

    create index(:paragraph, [:lang_id])
  end
end
