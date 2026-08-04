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
  # land in BigQuery, keyed by the session's cms_test_id
  # ("teacher-feedback:v2:<school>:<cycle>"), which the LMS derives from
  # (school_code, cycle_label) — so it is not duplicated as a column here.
  def change do
    create table(:lms_teacher_feedback) do
      # Grouping / identity
      add :setup_run_id, :uuid, null: false
      add :cycle_label, :string, size: 50, null: false

      # Scope. A round is defined by a CENTRE and its PROGRAMME, not by a school:
      # a school can host both a CoE and a Nodal centre, each with its own cohort,
      # and the LMS selects a round's batches by (school, centre programme). Both
      # ids are recorded so a historical row stays self-describing even if a centre
      # is renamed or re-pointed — resolve display names by joining `centres`.
      #
      # No FKs, matching lms_pm_school_visits: these rows are operational LMS data
      # written directly by the app, deliberately decoupled from db-service's
      # referential graph. Types still match their referents (both bigint) so the
      # joins need no casts.
      add :school_code, :string, size: 20, null: false
      add :centre_id, :bigint
      add :program_id, :bigint
      add :batch_class_ids, {:array, :string}, default: [], null: false

      # Teacher (id nullable: free-text fallback when no roster id is available)
      add :teacher_id, :string, size: 50
      add :teacher_name, :string, size: 255, null: false
      add :teacher_order, :integer, null: false

      # The db-service session this teacher's feedback round created. The
      # sessionCreator Lambda fills the quiz_id (session.platform_id) + portal /
      # admin links onto the SESSION row asynchronously; we resolve them by
      # joining on session_pk at read time, so they are not duplicated here.
      # bigint to match session.id.
      add :session_pk, :bigint

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
    create index(:lms_teacher_feedback, [:program_id])
    create index(:lms_teacher_feedback, [:setup_run_id])
    create index(:lms_teacher_feedback, [:session_pk])
    create index(:lms_teacher_feedback, [:school_code, :cycle_label])

    # Active rows for a school's cycles list
    create index(:lms_teacher_feedback, [:school_code, :cycle_label],
             where: "deleted_at IS NULL",
             name: :lms_teacher_feedback_active_idx
           )

    # One row per teacher per setup. Setup writes a row per teacher in a loop, so
    # without this a double-submit creates a second full set of rows AND a second
    # set of sessions: the cycles list shows every teacher twice and the report's
    # per-parameter denominator doubles. teacher_order is the per-setup teacher
    # key (teacher_id is nullable for the free-text fallback, so it cannot be).
    create unique_index(:lms_teacher_feedback, [:setup_run_id, :teacher_order],
             where: "deleted_at IS NULL",
             name: :lms_teacher_feedback_run_teacher_unique
           )
  end
end
