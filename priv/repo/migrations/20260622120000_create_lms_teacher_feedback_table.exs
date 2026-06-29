defmodule Dbservice.Repo.Migrations.CreateLmsTeacherFeedbackTable do
  use Ecto.Migration

  # Teacher Feedback: one row per teacher per setup. A Program Manager sets up a
  # student-feedback round for a centre + batch and a set of teachers; the LMS app
  # records the mapping here and creates one db-service session per teacher. The
  # sessionCreator Lambda then builds the quiz and fills the session's links.
  #
  # Operational LMS-owned data (like lms_pm_school_visits): the LMS app reads and
  # writes these rows directly via the pg pool. db-service owns the canonical
  # schema only; there is no schema/context/controller here.
  #
  # A "cycle" = rows sharing setup_run_id (all of one setup); they also share
  # (school_code, cycle_label). The quiz id and portal/admin links are resolved by
  # joining session_pk to the session table, not stored here. Feedback responses
  # land in BigQuery, keyed by source_id (= the session's cms_test_id).
  def change do
    create table(:lms_teacher_feedback) do
      # Grouping / identity
      add :setup_run_id, :uuid, null: false
      add :cycle_label, :string, size: 50, null: false
      add :source_id, :string, size: 255, null: false

      # Scope. Teachers map to a CENTRE (not a school): a school can have both a
      # CoE and a Nodal centre, so the PM picks a centre and we record it here.
      # No FK — this stays operational/decoupled like the rest of the table.
      add :school_code, :string, size: 20, null: false
      add :centre_id, :integer
      add :centre_name, :string, size: 255
      add :batch_class_ids, {:array, :string}, default: [], null: false

      # Teacher (id nullable: free-text fallback when no roster id is available)
      add :teacher_id, :string, size: 50
      add :teacher_name, :string, size: 255, null: false
      add :teacher_order, :integer, null: false

      # The db-service session this teacher's feedback round created. The
      # sessionCreator Lambda fills the quiz_id (session.platform_id) + portal /
      # admin links onto the SESSION row asynchronously; we resolve them by
      # joining on session_pk at read time, so they are not duplicated here.
      add :session_pk, :integer

      # Lifecycle: each teacher's setup can succeed or fail independently
      add :status, :string, size: 20, default: "pending", null: false

      # Response window, stored in UTC (this table's convention, like the
      # timestamps below). NOTE: the db-service `session` table stores the same
      # window in IST (its legacy convention), so these will read ~5.5h earlier
      # than session.start_time/end_time for the same round — do NOT compare them
      # raw. The LMS UI tags these as UTC and renders in the viewer's timezone.
      add :start_time, :naive_datetime
      add :end_time, :naive_datetime

      add :created_by, :string, size: 255, null: false

      # Soft delete
      add :deleted_at, :naive_datetime

      timestamps(default: fragment("(NOW() AT TIME ZONE 'UTC')"), null: false)
    end

    create constraint(:lms_teacher_feedback, :status_constraint,
             check: "status IN ('pending', 'created', 'failed')"
           )

    create index(:lms_teacher_feedback, [:school_code])
    create index(:lms_teacher_feedback, [:centre_id])
    create index(:lms_teacher_feedback, [:setup_run_id])
    create index(:lms_teacher_feedback, [:session_pk])
    create index(:lms_teacher_feedback, [:school_code, :cycle_label])

    # Active rows for a school's cycles list
    create index(:lms_teacher_feedback, [:school_code, :cycle_label],
             where: "deleted_at IS NULL",
             name: :lms_teacher_feedback_active_idx
           )
  end
end
