defmodule Dbservice.Repo.Migrations.CreateExamOccurrenceTable do
  use Ecto.Migration

  def change do
    create table(:exam_occurrence) do
      add :exam_id, references(:exam, on_delete: :nothing)
      add :year, :integer
      add :session, :integer
      add :registration_end_date, :string
      add :session_date, :string

      timestamps()
    end

    create index(:exam_occurrence, [:exam_id])
  end
end
