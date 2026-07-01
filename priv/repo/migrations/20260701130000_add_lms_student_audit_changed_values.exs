defmodule Dbservice.Repo.Migrations.AddLmsStudentAuditChangedValues do
  use Ecto.Migration

  def change do
    alter table(:lms_student_write_audits) do
      add :changed_values, :map, null: false, default: %{}
    end
  end
end
