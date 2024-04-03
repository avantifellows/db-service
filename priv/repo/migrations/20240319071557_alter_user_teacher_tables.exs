defmodule Dbservice.Repo.Migrations.AlterUserTeacherTables do
  use Ecto.Migration

  def change do
    alter table("user") do
      remove :middle_name
    end

    alter table("student") do
      add :grade_id, references("grade")
    end

    alter table("teacher") do
      add :subject_id, references("subject")

      remove :grade
      remove :school_id
      remove :subject
      remove :program_manager_id
    end
  end
end
