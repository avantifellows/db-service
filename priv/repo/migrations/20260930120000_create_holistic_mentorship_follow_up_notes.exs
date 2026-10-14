defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipFollowUpNotes do
  use Ecto.Migration

  # LMS-owned: the current Mentor adds immutable Follow-up Notes to a Phase after its
  # Post-Session Notes are submitted. Each row is its own audit, answering three fixed
  # questions keyed by stable column names. LMS writes these rows directly.
  def change do
    create table(:holistic_mentorship_follow_up_notes) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :phase_id, references(:holistic_mentorship_phases, on_delete: :nothing), null: false
      add :author_user_id, references(:user, on_delete: :nothing), null: false
      add :author_email, :string, size: 255, null: false
      add :challenges_answer, :text
      add :solutions_answer, :text
      add :action_plan_answer, :text
      add :submitted_at, :utc_datetime, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create index(
             :holistic_mentorship_follow_up_notes,
             [:student_id, :phase_id, :submitted_at],
             name: :hm_follow_up_notes_student_phase_time_idx
           )

    create index(:holistic_mentorship_follow_up_notes, [:phase_id],
             name: :hm_follow_up_notes_phase_idx
           )

    create index(:holistic_mentorship_follow_up_notes, [:author_user_id],
             name: :hm_follow_up_notes_author_idx
           )

    create constraint(
             :holistic_mentorship_follow_up_notes,
             :hm_follow_up_notes_author_email_check,
             check: "author_email ~ '[^[:space:]]'"
           )

    # Blank answers are stored as NULL; each stored answer is nonblank and bounded.
    create constraint(
             :holistic_mentorship_follow_up_notes,
             :hm_follow_up_notes_answers_check,
             check: """
             (challenges_answer IS NULL OR
              (challenges_answer ~ '[^[:space:]]' AND char_length(challenges_answer) <= 10000)) AND
             (solutions_answer IS NULL OR
              (solutions_answer ~ '[^[:space:]]' AND char_length(solutions_answer) <= 10000)) AND
             (action_plan_answer IS NULL OR
              (action_plan_answer ~ '[^[:space:]]' AND char_length(action_plan_answer) <= 10000))
             """
           )

    create constraint(
             :holistic_mentorship_follow_up_notes,
             :hm_follow_up_notes_any_answer_check,
             check: """
             challenges_answer IS NOT NULL OR
             solutions_answer IS NOT NULL OR
             action_plan_answer IS NOT NULL
             """
           )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_validate_follow_up_note()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        -- Serialize with privacy deletion for this Student, as other content writers do.
        PERFORM pg_advisory_xact_lock(NEW.student_id::integer, 0);

        IF EXISTS (
          SELECT 1 FROM holistic_mentorship_privacy_deletions deletion
          WHERE deletion.student_id = NEW.student_id
        ) THEN
          RAISE EXCEPTION 'Holistic Mentorship content is blocked after privacy deletion'
            USING ERRCODE = '23514';
        END IF;

        IF NOT EXISTS (
          SELECT 1
          FROM holistic_mentorship_post_session_notes AS notes
          WHERE notes.student_id = NEW.student_id
            AND notes.phase_id = NEW.phase_id
            AND notes.state = 'submitted'
        ) THEN
          RAISE EXCEPTION 'Follow-up Notes require submitted Post-Session Notes for the Phase'
            USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_validate_follow_up_note()"
    )

    execute(
      """
      CREATE TRIGGER hm_follow_up_notes_submitted_notes_check
      BEFORE INSERT ON holistic_mentorship_follow_up_notes
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_follow_up_note()
      """,
      "DROP TRIGGER hm_follow_up_notes_submitted_notes_check ON holistic_mentorship_follow_up_notes"
    )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_protect_follow_up_note()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Follow-up Notes are immutable'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_protect_follow_up_note()"
    )

    execute(
      """
      CREATE TRIGGER hm_follow_up_notes_immutable
      BEFORE UPDATE OR DELETE ON holistic_mentorship_follow_up_notes
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_protect_follow_up_note()
      """,
      "DROP TRIGGER hm_follow_up_notes_immutable ON holistic_mentorship_follow_up_notes"
    )
  end
end
