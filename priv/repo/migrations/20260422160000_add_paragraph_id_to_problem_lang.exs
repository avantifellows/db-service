defmodule Dbservice.Repo.Migrations.AddParagraphIdToProblemLang do
  use Ecto.Migration

  def change do
    alter table(:problem_lang) do
      add :paragraph_id, references(:paragraph, on_delete: :nilify_all)
    end

    create index(:problem_lang, [:paragraph_id])
  end
end
