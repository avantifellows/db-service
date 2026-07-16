defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipPhasePlans do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_phase_plans) do
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :academic_year, :string, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create table(:holistic_mentorship_phases) do
      add :phase_plan_id,
          references(:holistic_mentorship_phase_plans, on_delete: :nothing),
          null: false

      add :grade_id, references(:grade, on_delete: :nothing), null: false
      add :title, :string, null: false
      add :position, :integer, null: false
      add :state, :string, null: false
      add :guidance_markdown, :text, null: false
      add :revision, :integer, null: false
      add :frozen_at, :utc_datetime
      add :frozen_by_user_id, references(:user, on_delete: :nothing)

      timestamps(default: fragment("now()"), null: false)
    end

    create table(:holistic_mentorship_phase_questions) do
      add :phase_id, references(:holistic_mentorship_phases, on_delete: :nothing), null: false
      add :text, :text, null: false
      add :position, :integer, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:holistic_mentorship_phase_plans, [:program_id, :academic_year],
             name: :hm_phase_plan_scope_unique
           )

    create index(:holistic_mentorship_phase_plans, [:program_id],
             name: :hm_phase_plans_program_idx
           )

    create unique_index(:holistic_mentorship_phases, [:phase_plan_id, :position],
             name: :hm_phases_plan_position_unique
           )

    create index(:holistic_mentorship_phases, [:phase_plan_id, :grade_id, :state, :position],
             name: :hm_phases_plan_grade_state_position_idx
           )

    create index(:holistic_mentorship_phases, [:grade_id], name: :hm_phases_grade_idx)

    create index(:holistic_mentorship_phases, [:frozen_by_user_id],
             name: :hm_phases_frozen_by_user_idx
           )

    create unique_index(:holistic_mentorship_phase_questions, [:phase_id, :position],
             name: :hm_phase_questions_phase_position_unique
           )

    create index(:holistic_mentorship_phase_questions, [:phase_id],
             name: :hm_phase_questions_phase_idx
           )

    create constraint(:holistic_mentorship_phases, :hm_phases_position_check,
             check: "position > 0"
           )

    create constraint(:holistic_mentorship_phases, :hm_phases_state_check,
             check: "state IN ('locked', 'open')"
           )

    create constraint(:holistic_mentorship_phases, :hm_phases_revision_check,
             check: "revision > 0"
           )

    create constraint(
             :holistic_mentorship_phase_questions,
             :hm_phase_questions_position_check,
             check: "position BETWEEN 1 AND 4"
           )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_validate_phase_grade()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM grade WHERE id = NEW.grade_id AND number IN (11, 12)) THEN
          RAISE EXCEPTION 'Holistic Mentorship Phases require Grade 11 or 12'
            USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_validate_phase_grade()"
    )

    execute(
      """
      CREATE TRIGGER hm_phases_grade_check
      BEFORE INSERT OR UPDATE OF grade_id ON holistic_mentorship_phases
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_phase_grade()
      """,
      "DROP TRIGGER hm_phases_grade_check ON holistic_mentorship_phases"
    )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_protect_phase_grade()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF (NEW.number IS NULL OR NEW.number NOT IN (11, 12))
          AND EXISTS (SELECT 1 FROM holistic_mentorship_phases WHERE grade_id = NEW.id)
        THEN
          RAISE EXCEPTION 'A Grade used by Holistic Mentorship Phases must remain Grade 11 or 12'
            USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_protect_phase_grade()"
    )

    execute(
      """
      CREATE TRIGGER hm_grade_phase_scope_check
      BEFORE UPDATE OF number ON grade
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_protect_phase_grade()
      """,
      "DROP TRIGGER hm_grade_phase_scope_check ON grade"
    )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_validate_phase_question_count()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        target_phase_id bigint;
        question_count integer;
      BEGIN
        IF TG_TABLE_NAME = 'holistic_mentorship_phase_questions' THEN
          IF TG_OP = 'UPDATE'
            AND OLD.phase_id <> NEW.phase_id
            AND EXISTS (SELECT 1 FROM holistic_mentorship_phases WHERE id = OLD.phase_id)
          THEN
            SELECT count(*) INTO question_count
            FROM holistic_mentorship_phase_questions
            WHERE phase_id = OLD.phase_id;

            IF question_count NOT BETWEEN 1 AND 4 THEN
              RAISE EXCEPTION 'Holistic Mentorship Phase % must have one to four Questions', OLD.phase_id
                USING ERRCODE = '23514';
            END IF;
          END IF;
        END IF;

        IF TG_TABLE_NAME = 'holistic_mentorship_phases' THEN
          target_phase_id := NEW.id;
        ELSIF TG_OP = 'DELETE' THEN
          target_phase_id := OLD.phase_id;
        ELSE
          target_phase_id := NEW.phase_id;
        END IF;

        IF EXISTS (SELECT 1 FROM holistic_mentorship_phases WHERE id = target_phase_id) THEN
          SELECT count(*) INTO question_count
          FROM holistic_mentorship_phase_questions
          WHERE phase_id = target_phase_id;

          IF question_count NOT BETWEEN 1 AND 4 THEN
            RAISE EXCEPTION 'Holistic Mentorship Phase % must have one to four Questions', target_phase_id
              USING ERRCODE = '23514';
          END IF;
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_validate_phase_question_count()"
    )

    execute(
      """
      CREATE CONSTRAINT TRIGGER hm_phases_question_count
      AFTER INSERT OR UPDATE ON holistic_mentorship_phases
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_phase_question_count()
      """,
      "DROP TRIGGER hm_phases_question_count ON holistic_mentorship_phases"
    )

    execute(
      """
      CREATE CONSTRAINT TRIGGER hm_phase_questions_count
      AFTER INSERT OR UPDATE OR DELETE ON holistic_mentorship_phase_questions
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_phase_question_count()
      """,
      "DROP TRIGGER hm_phase_questions_count ON holistic_mentorship_phase_questions"
    )
  end
end
