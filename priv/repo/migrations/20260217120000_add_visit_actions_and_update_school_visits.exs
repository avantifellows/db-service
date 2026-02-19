defmodule Dbservice.Repo.Migrations.AddVisitActionsAndUpdateSchoolVisits do
  use Ecto.Migration

  def up do
    # ── 0.1  Create lms_pm_visit_actions table ──────────────────────────

    create table(:lms_pm_visit_actions) do
      add :visit_id, references(:lms_pm_school_visits, on_delete: :delete_all), null: false

      # Action identification (validated in app code; no DB CHECK on type)
      add :action_type, :string, size: 50, null: false

      # Soft delete
      add :deleted_at, :naive_datetime

      # Geo tracking - Start
      add :started_at, :naive_datetime
      add :start_lat, :decimal, precision: 10, scale: 8
      add :start_lng, :decimal, precision: 11, scale: 8
      add :start_accuracy, :decimal, precision: 10, scale: 2

      # Geo tracking - End
      add :ended_at, :naive_datetime
      add :end_lat, :decimal, precision: 10, scale: 8
      add :end_lng, :decimal, precision: 11, scale: 8
      add :end_accuracy, :decimal, precision: 10, scale: 2

      # Status
      add :status, :string, size: 20, default: "pending", null: false

      # Action-specific form data
      add :data, :map, default: %{}

      timestamps(default: fragment("(NOW() AT TIME ZONE 'UTC')"), null: false)
    end

    # Status values
    create constraint(:lms_pm_visit_actions, :lms_pm_visit_actions_status_check,
             check: "status IN ('pending', 'in_progress', 'completed')"
           )

    # Soft delete only allowed for pending actions
    create constraint(:lms_pm_visit_actions, :lms_pm_visit_actions_deleted_pending_check,
             check: "deleted_at IS NULL OR status = 'pending'"
           )

    # Status ↔ timestamp consistency
    create constraint(:lms_pm_visit_actions, :lms_pm_visit_actions_status_timestamps_check,
             check: """
             (status = 'pending'     AND started_at IS NULL AND ended_at IS NULL) OR
             (status = 'in_progress' AND started_at IS NOT NULL AND ended_at IS NULL) OR
             (status = 'completed'   AND started_at IS NOT NULL AND ended_at IS NOT NULL)
             """
           )

    # End cannot precede start
    create constraint(:lms_pm_visit_actions, :lms_pm_visit_actions_time_order_check,
             check: "ended_at IS NULL OR ended_at >= started_at"
           )

    # Index for querying actions by visit
    create index(:lms_pm_visit_actions, [:visit_id], name: :idx_visit_actions_visit_id)

    # ── 0.2  Alter lms_pm_school_visits ─────────────────────────────────

    # Drop the ended_at index before removing the column
    drop_if_exists index(:lms_pm_school_visits, [:ended_at])

    alter table(:lms_pm_school_visits) do
      add :completed_at, :naive_datetime
      remove :data
      remove :ended_at
    end
  end

  def down do
    # Restore visit columns
    alter table(:lms_pm_school_visits) do
      add :ended_at, :naive_datetime
      add :data, :map, default: %{}, null: false
      remove :completed_at
    end

    create index(:lms_pm_school_visits, [:ended_at])

    # Drop actions table (constraints + indexes dropped with it)
    drop table(:lms_pm_visit_actions)
  end
end
