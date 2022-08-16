defmodule Dbservice.Repo.Migrations.CreateStudentProgram do
  use Ecto.Migration

  def change do
    create table(:student_program) do
      add :student_id, references(:student, on_delete: :nothing)
      add :program_id, references(:program, on_delete: :nothing)
      add :program_manager_id, references(:user, on_delete: :nothing)
      add :is_high_touch, :string

      timestamps()
    end

    create index(:student_program, [:student_id])
    create index(:student_program, [:program_id])
    create index(:student_program, [:program_manager_id])
  end
end
