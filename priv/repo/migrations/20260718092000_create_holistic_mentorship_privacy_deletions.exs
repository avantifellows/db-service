defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipPrivacyDeletions do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_privacy_deletions) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :actor_user_id, references(:user, on_delete: :nothing), null: false
      add :reason, :text, null: false
      add :profile_summaries_erased, :integer, null: false
      add :post_session_answers_erased, :integer, null: false
      add :historical_answers_erased, :integer, null: false
      add :occurred_at, :utc_datetime, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(
             :holistic_mentorship_privacy_deletions,
             [:student_id],
             name: :hm_privacy_deletions_student_uidx
           )

    create constraint(
             :holistic_mentorship_privacy_deletions,
             :hm_privacy_deletions_content_check,
             check: """
             btrim(reason) <> ''
             AND profile_summaries_erased >= 0
             AND post_session_answers_erased >= 0
             AND historical_answers_erased >= 0
             """
           )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_protect_privacy_deletion()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Holistic Mentorship privacy deletions are immutable'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_protect_privacy_deletion()"
    )

    execute(
      """
      CREATE TRIGGER hm_privacy_deletions_immutable
      BEFORE UPDATE OR DELETE ON holistic_mentorship_privacy_deletions
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_protect_privacy_deletion()
      """,
      "DROP TRIGGER hm_privacy_deletions_immutable ON holistic_mentorship_privacy_deletions"
    )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_reject_erased_student_content()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        target_student_id bigint;
      BEGIN
        IF TG_TABLE_NAME = 'holistic_mentorship_student_profile_summaries' THEN
          SELECT journey.student_id INTO target_student_id
          FROM holistic_mentorship_student_profiles profile
          JOIN holistic_mentorship_profile_journeys journey
            ON journey.id = profile.profile_journey_id
          WHERE profile.id = NEW.student_profile_id;
        ELSIF TG_TABLE_NAME = 'holistic_mentorship_post_session_answers' THEN
          SELECT notes.student_id INTO target_student_id
          FROM holistic_mentorship_post_session_notes notes
          WHERE notes.id = NEW.notes_id;
        ELSIF TG_TABLE_NAME = 'holistic_mentorship_historical_note_answers' THEN
          SELECT notes.student_id INTO target_student_id
          FROM holistic_mentorship_historical_notes notes
          WHERE notes.id = NEW.historical_note_id;
        END IF;

        -- Serialize every content writer with privacy deletion for this Student.
        PERFORM pg_advisory_xact_lock(target_student_id::integer, 0);

        IF EXISTS (
          SELECT 1 FROM holistic_mentorship_privacy_deletions deletion
          WHERE deletion.student_id = target_student_id
        ) THEN
          RAISE EXCEPTION 'Holistic Mentorship content is blocked after privacy deletion'
            USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_reject_erased_student_content()"
    )

    for {table, trigger} <- [
          {:holistic_mentorship_student_profile_summaries, :hm_profile_summaries_privacy_guard},
          {:holistic_mentorship_post_session_answers, :hm_post_session_answers_privacy_guard},
          {:holistic_mentorship_historical_note_answers,
           :hm_historical_note_answers_privacy_guard}
        ] do
      execute(
        """
        CREATE TRIGGER #{trigger}
        BEFORE INSERT OR UPDATE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_reject_erased_student_content()
        """,
        "DROP TRIGGER #{trigger} ON #{table}"
      )
    end
  end
end
