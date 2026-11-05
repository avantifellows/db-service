defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipPostSessionNoteChallenges do
  use Ecto.Migration

  # LMS-owned (af_lms#457): the Challenge Categories a Mentor selects in Post-Session
  # Notes, one row per selected stable category code. LMS owns the code list and
  # validates codes (ADR-0004 stable-code pattern), so there is no CHECK on values.
  # Rows are content of the Notes, so they share the post_session_answers privacy guard.

  # Body installed by 20260718092000_create_holistic_mentorship_privacy_deletions.
  @previous_privacy_guard """
  CREATE OR REPLACE FUNCTION holistic_mentorship_reject_erased_student_content()
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
  """

  @privacy_guard """
  CREATE OR REPLACE FUNCTION holistic_mentorship_reject_erased_student_content()
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
    ELSIF TG_TABLE_NAME IN (
      'holistic_mentorship_post_session_answers',
      'holistic_mentorship_post_session_note_challenges'
    ) THEN
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
  """

  def up do
    create table(:holistic_mentorship_post_session_note_challenges) do
      add :notes_id,
          references(:holistic_mentorship_post_session_notes, on_delete: :nothing),
          null: false

      add :category_code, :string, size: 100, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    # Leading notes_id also serves per-Notes lookups, so no separate notes_id index.
    create unique_index(
             :holistic_mentorship_post_session_note_challenges,
             [:notes_id, :category_code],
             name: :hm_post_session_note_challenges_notes_category_unique
           )

    create constraint(
             :holistic_mentorship_post_session_note_challenges,
             :hm_post_session_note_challenges_category_code_check,
             check: "category_code ~ '[^[:space:]]'"
           )

    execute(@privacy_guard)

    execute("""
    CREATE TRIGGER hm_post_session_note_challenges_privacy_guard
    BEFORE INSERT OR UPDATE ON holistic_mentorship_post_session_note_challenges
    FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_reject_erased_student_content()
    """)
  end

  def down do
    execute(
      "DROP TRIGGER hm_post_session_note_challenges_privacy_guard ON holistic_mentorship_post_session_note_challenges"
    )

    execute(@previous_privacy_guard)

    drop table(:holistic_mentorship_post_session_note_challenges)
  end
end
