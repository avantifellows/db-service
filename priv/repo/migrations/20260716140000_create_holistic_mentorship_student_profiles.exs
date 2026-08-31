defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipStudentProfiles do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_profile_journeys) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :form_id, :string, null: false
      add :af_session_id, :string, null: false
      add :entry_grade, :integer, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create table(:holistic_mentorship_student_profiles) do
      add :profile_journey_id,
          references(:holistic_mentorship_profile_journeys, on_delete: :nothing),
          null: false

      add :prompt_configuration_id,
          references(:holistic_mentorship_prompt_configurations, on_delete: :nothing),
          null: false

      add :schema_fingerprint, :string, null: false
      add :answer_fingerprint, :string, null: false
      add :warehouse_loaded_at, :utc_datetime, null: false
      add :generated_at, :utc_datetime, null: false
      add :revision, :integer, null: false
      add :last_successful_etl_run_id, :string, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create table(:holistic_mentorship_student_profile_summaries) do
      add :student_profile_id,
          references(:holistic_mentorship_student_profiles, on_delete: :delete_all),
          null: false

      add :position, :integer, null: false
      add :question_set_title, :string, null: false
      add :summary, :text, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:holistic_mentorship_profile_journeys, [:student_id],
             name: :hm_profile_journeys_student_unique
           )

    create unique_index(
             :holistic_mentorship_student_profiles,
             [:profile_journey_id, :prompt_configuration_id],
             name: :hm_student_profiles_journey_configuration_unique
           )

    create constraint(:holistic_mentorship_student_profiles, :hm_student_profiles_revision_check,
             check: "revision > 0"
           )

    create unique_index(
             :holistic_mentorship_student_profile_summaries,
             [:student_profile_id, :position],
             name: :hm_student_profile_summaries_profile_position_unique
           )

    create constraint(
             :holistic_mentorship_student_profile_summaries,
             :hm_student_profile_summaries_position_check,
             check: "position BETWEEN 1 AND 5"
           )

    create constraint(
             :holistic_mentorship_student_profile_summaries,
             :hm_student_profile_summaries_content_check,
             check: "btrim(question_set_title) <> '' AND btrim(summary) <> ''"
           )

    create constraint(:holistic_mentorship_profile_journeys, :hm_profile_journeys_source_check,
             check: """
             (form_id = '6a44a83d1184e717b920c499'
              AND af_session_id = 'EnableStudents_6a44a83d1184e717b920c499'
              AND entry_grade = 11)
             OR
             (form_id = '6a4deca8e030ebe34669fb0f'
              AND af_session_id = 'EnableStudents_6a4deca8e030ebe34669fb0f'
              AND entry_grade = 12)
             """
           )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_protect_profile_journey()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.student_id IS DISTINCT FROM OLD.student_id
          OR NEW.form_id IS DISTINCT FROM OLD.form_id
          OR NEW.af_session_id IS DISTINCT FROM OLD.af_session_id
          OR NEW.entry_grade IS DISTINCT FROM OLD.entry_grade
        THEN
          RAISE EXCEPTION 'Profile journey identity is immutable' USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_protect_profile_journey()"
    )

    execute(
      """
      CREATE TRIGGER hm_profile_journeys_immutable
      BEFORE UPDATE ON holistic_mentorship_profile_journeys
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_protect_profile_journey()
      """,
      "DROP TRIGGER hm_profile_journeys_immutable ON holistic_mentorship_profile_journeys"
    )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_validate_profile_summary_count()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        target_profile_id bigint;
        summary_count integer;
      BEGIN
        IF TG_TABLE_NAME = 'holistic_mentorship_student_profile_summaries' THEN
          IF TG_OP = 'UPDATE'
            AND OLD.student_profile_id <> NEW.student_profile_id
            AND EXISTS (SELECT 1 FROM holistic_mentorship_student_profiles WHERE id = OLD.student_profile_id)
          THEN
            SELECT count(*) INTO summary_count
            FROM holistic_mentorship_student_profile_summaries
            WHERE student_profile_id = OLD.student_profile_id;

            IF summary_count <> 5 THEN
              RAISE EXCEPTION 'Student Profile must have exactly five summaries'
                USING ERRCODE = '23514';
            END IF;
          END IF;
        END IF;

        IF TG_TABLE_NAME = 'holistic_mentorship_student_profiles' THEN
          target_profile_id := NEW.id;
        ELSIF TG_OP = 'DELETE' THEN
          target_profile_id := OLD.student_profile_id;
        ELSE
          target_profile_id := NEW.student_profile_id;
        END IF;

        IF EXISTS (SELECT 1 FROM holistic_mentorship_student_profiles WHERE id = target_profile_id) THEN
          SELECT count(*) INTO summary_count
          FROM holistic_mentorship_student_profile_summaries
          WHERE student_profile_id = target_profile_id;

          IF summary_count <> 5 THEN
            RAISE EXCEPTION 'Student Profile must have exactly five summaries'
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
      "DROP FUNCTION holistic_mentorship_validate_profile_summary_count()"
    )

    execute(
      """
      CREATE CONSTRAINT TRIGGER hm_student_profiles_summary_count
      AFTER INSERT OR UPDATE ON holistic_mentorship_student_profiles
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_profile_summary_count()
      """,
      "DROP TRIGGER hm_student_profiles_summary_count ON holistic_mentorship_student_profiles"
    )

    execute(
      """
      CREATE CONSTRAINT TRIGGER hm_student_profile_summaries_count
      AFTER INSERT OR UPDATE OR DELETE ON holistic_mentorship_student_profile_summaries
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_profile_summary_count()
      """,
      "DROP TRIGGER hm_student_profile_summaries_count ON holistic_mentorship_student_profile_summaries"
    )
  end
end
