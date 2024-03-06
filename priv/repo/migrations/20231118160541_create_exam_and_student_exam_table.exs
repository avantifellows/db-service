defmodule Dbservice.Repo.Migrations.CreateExamAndStudentExamTable do
  use Ecto.Migration

  def change do
    create table(:exam) do
      add :name, :string
      add :registration_deadline, :utc_datetime
      add :date, :utc_datetime

      timestamps()
    end

    create table(:student_exam_record) do
      add :student_id, references(:student, on_delete: :nothing)
      add :exam_id, references(:exam, on_delete: :nothing)
      add :application_number, :string
      add :application_password, :string
      add :date, :utc_datetime
      add :score, :float
      add :rank, :integer

      timestamps()
    end
  end
end
