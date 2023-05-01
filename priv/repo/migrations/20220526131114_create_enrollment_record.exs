defmodule Dbservice.Repo.Migrations.CreateEnrollmentRecord do
  use Ecto.Migration

  def change do
    create table(:enrollment_record) do
      add :grade, :string
      add :academic_year, :string
      add :is_current, :boolean, default: false, null: false
      add :student_id, references(:student, on_delete: :nothing)
      add :school_id, references(:school, on_delete: :nothing)

      timestamps()
    end

    create index(:enrollment_record, [:student_id])
    create index(:enrollment_record, [:school_id])
  end
end
