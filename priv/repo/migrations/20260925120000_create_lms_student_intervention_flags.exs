defmodule Dbservice.Repo.Migrations.CreateLmsStudentInterventionFlags do
  use Ecto.Migration

  # LMS-owned: teachers flag a Student who needs special (non-academic) intervention —
  # medical, mental health, grief, extra attention. The LMS app reads and writes these
  # tables directly, so there is no schema/context/controller here.
  #
  # A flag is the case; every change to it (raise, follow-up note, resolve) is an
  # append-only update row. Update rows are immutable except that `body` may be cleared
  # to NULL, which is how a future privacy erasure removes a note without losing history.
  def change do
    create table(:lms_student_intervention_flags) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      # Snapshotted at raise time: scopes the cross-school view and survives transfers.
      add :school_id, references(:school, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing)
      add :status, :string, null: false
      add :raised_by_email, :string, size: 255, null: false
      add :raised_by_user_id, references(:user, on_delete: :nothing)
      add :resolved_at, :utc_datetime

      timestamps(default: fragment("now()"), null: false)
    end

    create table(:lms_student_intervention_flag_updates) do
      add :flag_id, references(:lms_student_intervention_flags, on_delete: :nothing), null: false

      add :author_email, :string, size: 255, null: false
      add :author_user_id, references(:user, on_delete: :nothing)
      add :body, :text
      add :status_from, :string
      add :status_to, :string

      timestamps(default: fragment("now()"), null: false, updated_at: false)
    end

    # Follow-ups go on the existing open flag, so a Student has at most one open case.
    create unique_index(:lms_student_intervention_flags, [:student_id],
             where: "status = 'open'",
             name: :lms_intervention_flags_one_open_per_student
           )

    create index(:lms_student_intervention_flags, [:school_id, :status],
             name: :lms_intervention_flags_school_status_idx
           )

    create index(:lms_student_intervention_flag_updates, [:flag_id, :inserted_at],
             name: :lms_intervention_flag_updates_flag_time_idx
           )

    create constraint(:lms_student_intervention_flags, :lms_intervention_flags_status_check,
             check: "status IN ('open', 'resolved')"
           )

    create constraint(
             :lms_student_intervention_flags,
             :lms_intervention_flags_resolved_at_check,
             check: "(status = 'resolved') = (resolved_at IS NOT NULL)"
           )

    create constraint(
             :lms_student_intervention_flag_updates,
             :lms_intervention_flag_updates_status_check,
             check: """
             (status_from IS NULL OR status_from IN ('open', 'resolved')) AND
             (status_to IS NULL OR status_to IN ('open', 'resolved'))
             """
           )

    execute(
      """
      CREATE FUNCTION lms_protect_intervention_flag_updates()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'UPDATE'
           AND NEW.body IS NULL
           AND (NEW.id, NEW.flag_id, NEW.author_email, NEW.author_user_id,
                NEW.status_from, NEW.status_to, NEW.inserted_at)
               IS NOT DISTINCT FROM
               (OLD.id, OLD.flag_id, OLD.author_email, OLD.author_user_id,
                OLD.status_from, OLD.status_to, OLD.inserted_at) THEN
          RETURN NEW;
        END IF;

        RAISE EXCEPTION 'Intervention flag updates are append-only (only body may be cleared)'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION lms_protect_intervention_flag_updates()"
    )

    execute(
      """
      CREATE TRIGGER lms_intervention_flag_updates_append_only
      BEFORE UPDATE OR DELETE ON lms_student_intervention_flag_updates
      FOR EACH ROW EXECUTE FUNCTION lms_protect_intervention_flag_updates()
      """,
      "DROP TRIGGER lms_intervention_flag_updates_append_only ON lms_student_intervention_flag_updates"
    )
  end
end
