defmodule Dbservice.Repo.Migrations.AddIndexesToStudentAndUserTables do
  use Ecto.Migration

  def change do
    # Add index on student table for apaar_id
    create index(:student, [:apaar_id], name: "index_student_on_apaar_id")

    # Add index on student table for student_id
    create index(:student, [:student_id], name: "index_student_on_student_id")
  end
end
