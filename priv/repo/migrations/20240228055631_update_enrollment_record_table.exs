defmodule Dbservice.Repo.Migrations.UpdateEnrollmentRecordTable do
  use Ecto.Migration

  def change do
    alter table(:enrollment_record) do
      remove :date_of_school_enrollment
      remove :date_of_group_enrollment
      remove :group_id

      add :date_of_enrollment, :date
      add :grouping_id, :integer
      add :grouping_type, :string
    end
  end
end
