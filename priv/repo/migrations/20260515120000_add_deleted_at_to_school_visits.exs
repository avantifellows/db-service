defmodule Dbservice.Repo.Migrations.AddDeletedAtToSchoolVisits do
  use Ecto.Migration

  def up do
    alter table(:lms_pm_school_visits) do
      add :deleted_at, :naive_datetime
    end
  end

  def down do
    alter table(:lms_pm_school_visits) do
      remove :deleted_at
    end
  end
end
