defmodule Dbservice.Repo.Migrations.AddGeoTrackingToLmsPmSchoolVisits do
  use Ecto.Migration

  def up do
    alter table(:lms_pm_school_visits) do
      # Start GPS (captured when visit is created)
      add :start_lat, :decimal, precision: 10, scale: 8
      add :start_lng, :decimal, precision: 11, scale: 8
      add :start_accuracy, :decimal, precision: 10, scale: 2

      # End timestamp + GPS (captured when PM ends visit)
      add :ended_at, :naive_datetime
      add :end_lat, :decimal, precision: 10, scale: 8
      add :end_lng, :decimal, precision: 11, scale: 8
      add :end_accuracy, :decimal, precision: 10, scale: 2
    end

    # Index for querying un-ended or recently ended visits
    create index(:lms_pm_school_visits, [:ended_at])
  end

  def down do
    drop index(:lms_pm_school_visits, [:ended_at])

    alter table(:lms_pm_school_visits) do
      remove :start_lat
      remove :start_lng
      remove :start_accuracy
      remove :ended_at
      remove :end_lat
      remove :end_lng
      remove :end_accuracy
    end
  end
end
