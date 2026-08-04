defmodule Dbservice.Repo.Migrations.CreateLmsTeacherFeedbackTable do
  use Ecto.Migration

  # Teacher Feedback: one row per teacher per setup run (grouped by setup_run_id).
  # Operational LMS-owned data like lms_pm_school_visits — the LMS app reads and
  # writes it directly, so there is no schema/context/controller here.
  def change do
    create table(:lms_teacher_feedback) do
      add :setup_run_id, :uuid, null: false
      add :cycle_label, :string, size: 50, null: false

      # A round's cohort is (school, centre programme) — a school can host both a
      # CoE and a Nodal centre. bigint matches the referents; no FKs (see above).
      add :school_code, :string, size: 20, null: false
      add :centre_id, :bigint
      add :program_id, :bigint
      add :batch_class_ids, {:array, :string}, default: [], null: false

      # teacher_id is null for the free-text fallback.
      add :teacher_id, :string, size: 50
      add :teacher_name, :string, size: 255, null: false
      add :teacher_order, :integer, null: false

      # Quiz id and links live on the session row, not here.
      add :session_pk, :bigint

      # Each teacher's setup succeeds or fails independently.
      add :status, :string, size: 20, default: "pending", null: false

      # UTC. The `session` table stores the same window in IST, so these read
      # ~5.5h earlier for the same round — never compare the two raw.
      add :start_time, :naive_datetime
      add :end_time, :naive_datetime

      add :created_by, :string, size: 255, null: false

      add :deleted_at, :naive_datetime

      timestamps(default: fragment("(NOW() AT TIME ZONE 'UTC')"), null: false)
    end

    create constraint(:lms_teacher_feedback, :status_constraint,
             check: "status IN ('pending', 'created', 'failed')"
           )

    create index(:lms_teacher_feedback, [:school_code])
    create index(:lms_teacher_feedback, [:centre_id])
    create index(:lms_teacher_feedback, [:program_id])
    create index(:lms_teacher_feedback, [:setup_run_id])
    create index(:lms_teacher_feedback, [:session_pk])
    create index(:lms_teacher_feedback, [:school_code, :cycle_label])

    create index(:lms_teacher_feedback, [:school_code, :cycle_label],
             where: "deleted_at IS NULL",
             name: :lms_teacher_feedback_active_idx
           )

    # Scoped to one run: a second submit mints a new setup_run_id, so this is not
    # double-submit protection.
    create unique_index(:lms_teacher_feedback, [:setup_run_id, :teacher_order],
             where: "deleted_at IS NULL",
             name: :lms_teacher_feedback_run_teacher_unique
           )
  end
end
