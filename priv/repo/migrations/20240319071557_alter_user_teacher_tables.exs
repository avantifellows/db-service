defmodule Dbservice.Repo.Migrations.AlterUserTeacherTables do
  use Ecto.Migration

  def change do
    alter table("user") do
      remove :middle_name
    end

    alter table("teacher") do
      remove :subject
      remove :grade
      remove :school_id
      remove :program_manager_id
    end
  end
end
