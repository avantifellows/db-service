defmodule Dbservice.Repo.Migrations.AlterStudentExamRecordTable do
  use Ecto.Migration

  def change do
    alter table(:student_exam_record) do
      modify :date, :date, null: true
    end
  end
end
