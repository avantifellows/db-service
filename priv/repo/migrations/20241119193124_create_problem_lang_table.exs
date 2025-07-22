defmodule Dbservice.Repo.Migrations.CreateProblemLangTable do
  use Ecto.Migration

  def up do
    create table(:problem_lang) do
      add :res_id, references(:resource)
      add :lang_id, references(:language)
      add :meta_data, :jsonb

      timestamps()
    end
  end

  def down do
    drop table(:problem_lang)
  end
end
