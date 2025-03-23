defmodule Dbservice.Repo.Migrations.RemoveGradeIdFromGrade do
  use Ecto.Migration

  def change do
    alter table(:enrollment_record) do
      remove :grade_id
    end
  end
end
