defmodule Dbservice.Repo.Migrations.AddColumnToEnrollmentRecord do
  use Ecto.Migration

  def change do
    alter table(:enrollment_record) do
      remove :date_of_enrollment
      add :group_id, references(:group, on_delete: :nothing)
      add :date_of_school_enrollment, :date
      add :date_of_group_enrollment, :date
    end
  end
end
