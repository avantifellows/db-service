defmodule Dbservice.Repo.Migrations.AlterUserTeacherTables do
  use Ecto.Migration

  def change do
    alter table("user") do
      remove :middle_name
      modify :subject_id, references("subject")
    end

    alter table("student") do
      add :grade_id, references("grade")
    end

    alter table("teacher") do
      remove :grade
      remove :school_id
      remove :program_manager_id
    end
  end
end
