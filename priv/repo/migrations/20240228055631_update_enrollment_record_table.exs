defmodule Dbservice.Repo.Migrations.UpdateEnrollmentRecordTable do
  use Ecto.Migration

  def change do
    alter table(:enrollment_record) do
      remove :date_of_school_enrollment
      remove :date_of_group_enrollment
      add :date_of_enrollment, :date
      add :group_id, :integer
      add :group_type, :string
    end
  end
end
