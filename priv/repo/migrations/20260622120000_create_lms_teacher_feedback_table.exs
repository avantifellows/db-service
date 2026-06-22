defmodule Dbservice.Repo.Migrations.CreateLmsTeacherFeedbackTable do
  use Ecto.Migration

  # Teacher Feedback: one row per teacher per setup. A Program Manager sets up a
  # student-feedback round for a school+batch and a set of teachers; the LMS app
  # creates one quiz + one session per teacher and records the mapping here.
  #
  # Operational LMS-owned data (like lms_pm_school_visits): the LMS app reads and
  # writes these rows directly via the pg pool. db-service owns the canonical
  # schema only; there is no schema/context/controller here.
  #
  # A "cycle" = rows sharing setup_run_id (all of one setup); they also share
  # (school_code, cycle_label). Feedback responses live in BigQuery and are joined
  # by quiz_id (= BigQuery test_id) / source_id (= BigQuery cms_test_id).
  def change do
    create table(:lms_teacher_feedback) do
      # Grouping / identity
      add :setup_run_id, :uuid, null: false
      add :cycle_label, :string, size: 50, null: false
      add :source_id, :string, size: 255, null: false

      # Scope
      add :school_code, :string, size: 20, null: false
      add :batch_parent_id, :string, size: 255, null: false
      add :batch_class_ids, {:array, :string}, default: [], null: false
      add :grade, :integer, null: false

      # Teacher (id nullable: free-text fallback when no roster id is available)
      add :teacher_id, :string, size: 50
      add :teacher_name, :string, size: 255, null: false
      add :teacher_order, :integer, null: false

      # Created artifacts (quiz-backend quiz + db-service session)
      add :quiz_id, :string, size: 255
      add :session_pk, :integer
      add :session_id, :string, size: 255

      # Lifecycle: each teacher's setup can succeed or fail independently
      add :status, :string, size: 20, default: "pending", null: false

      # Response window (stored UTC)
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
    create index(:lms_teacher_feedback, [:setup_run_id])
    create index(:lms_teacher_feedback, [:quiz_id])
    create index(:lms_teacher_feedback, [:school_code, :cycle_label])

    # Active rows for a school's cycles list
    create index(:lms_teacher_feedback, [:school_code, :cycle_label],
             where: "deleted_at IS NULL",
             name: :lms_teacher_feedback_active_idx
           )
  end
end
