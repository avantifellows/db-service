defmodule Dbservice.Repo.Migrations.AlterEnrollmentRecordTable do
  use Ecto.Migration

  def change do
    alter table(:enrollment_record) do
      remove :school_id
      remove :group_type
      remove :group_id

      add :grouping_id, :integer
      add :grouping_type, :string
    end
  end
end
