defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipPostSessionNotes do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_post_session_notes) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :phase_id, references(:holistic_mentorship_phases, on_delete: :nothing), null: false
      add :author_user_id, references(:user, on_delete: :nothing), null: false
      add :state, :string, null: false
      add :revision, :integer, null: false
      add :first_drafted_at, :utc_datetime, null: false
      add :first_submitted_at, :utc_datetime
      add :last_edited_at, :utc_datetime, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create table(:holistic_mentorship_post_session_answers) do
      add :notes_id,
          references(:holistic_mentorship_post_session_notes, on_delete: :nothing),
          null: false

      add :question_id,
          references(:holistic_mentorship_phase_questions, on_delete: :nothing),
          null: false

      add :answer, :text, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create table(:holistic_mentorship_post_session_note_audits) do
      add :notes_id,
          references(:holistic_mentorship_post_session_notes, on_delete: :nothing),
          null: false

      add :actor_user_id, references(:user, on_delete: :nothing), null: false
      add :action, :string, null: false
      add :occurred_at, :utc_datetime, null: false
      add :reason, :string

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:holistic_mentorship_post_session_notes, [:student_id, :phase_id],
             name: :hm_post_session_notes_student_phase_unique
           )

    create index(:holistic_mentorship_post_session_notes, [:phase_id],
             name: :hm_post_session_notes_phase_idx
           )

    create index(:holistic_mentorship_post_session_notes, [:author_user_id],
             name: :hm_post_session_notes_author_idx
           )

    create unique_index(:holistic_mentorship_post_session_answers, [:notes_id, :question_id],
             name: :hm_post_session_answers_notes_question_unique
           )

    create index(:holistic_mentorship_post_session_answers, [:question_id],
             name: :hm_post_session_answers_question_idx
           )

    create index(:holistic_mentorship_post_session_note_audits, [:notes_id, :occurred_at],
             name: :hm_post_session_note_audits_notes_time_idx
           )

    create index(:holistic_mentorship_post_session_note_audits, [:actor_user_id],
             name: :hm_post_session_note_audits_actor_idx
           )

    create constraint(:holistic_mentorship_post_session_notes, :hm_post_session_notes_state_check,
             check: "state IN ('draft', 'submitted')"
           )

    create constraint(
             :holistic_mentorship_post_session_notes,
             :hm_post_session_notes_revision_check,
             check: "revision > 0"
           )

    create constraint(
             :holistic_mentorship_post_session_notes,
             :hm_post_session_notes_timeline_check,
             check: """
             last_edited_at >= first_drafted_at AND
             ((state = 'draft' AND first_submitted_at IS NULL) OR
              (state = 'submitted' AND first_submitted_at IS NOT NULL AND
               first_submitted_at BETWEEN first_drafted_at AND last_edited_at))
             """
           )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_validate_notes_answer_phase()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_TABLE_NAME = 'holistic_mentorship_post_session_answers' THEN
          IF NOT EXISTS (
            SELECT 1
            FROM holistic_mentorship_post_session_notes AS notes
            JOIN holistic_mentorship_phase_questions AS question
              ON question.id = NEW.question_id AND question.phase_id = notes.phase_id
            WHERE notes.id = NEW.notes_id
          ) THEN
            RAISE EXCEPTION 'Post-Session Answer Question must belong to the Notes Phase'
              USING ERRCODE = '23514';
          END IF;
        ELSIF TG_TABLE_NAME = 'holistic_mentorship_post_session_notes' THEN
          IF EXISTS (
            SELECT 1
            FROM holistic_mentorship_post_session_answers AS answer
            JOIN holistic_mentorship_phase_questions AS question ON question.id = answer.question_id
            WHERE answer.notes_id = NEW.id AND question.phase_id <> NEW.phase_id
          ) THEN
            RAISE EXCEPTION 'Post-Session Notes Phase conflicts with an Answer Question'
              USING ERRCODE = '23514';
          END IF;
        ELSIF TG_TABLE_NAME = 'holistic_mentorship_phase_questions' THEN
          IF EXISTS (
            SELECT 1
            FROM holistic_mentorship_post_session_answers AS answer
            JOIN holistic_mentorship_post_session_notes AS notes ON notes.id = answer.notes_id
            WHERE answer.question_id = NEW.id AND notes.phase_id <> NEW.phase_id
          ) THEN
            RAISE EXCEPTION 'Phase Question conflicts with existing Post-Session Notes Answers'
              USING ERRCODE = '23514';
          END IF;
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_validate_notes_answer_phase()"
    )

    execute(
      """
      CREATE TRIGGER hm_post_session_answers_phase_check
      BEFORE INSERT OR UPDATE OF notes_id, question_id ON holistic_mentorship_post_session_answers
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_notes_answer_phase()
      """,
      "DROP TRIGGER hm_post_session_answers_phase_check ON holistic_mentorship_post_session_answers"
    )

    execute(
      """
      CREATE TRIGGER hm_post_session_notes_answer_phase_check
      BEFORE UPDATE OF phase_id ON holistic_mentorship_post_session_notes
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_notes_answer_phase()
      """,
      "DROP TRIGGER hm_post_session_notes_answer_phase_check ON holistic_mentorship_post_session_notes"
    )

    execute(
      """
      CREATE TRIGGER hm_phase_questions_notes_answer_phase_check
      BEFORE UPDATE OF phase_id ON holistic_mentorship_phase_questions
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_notes_answer_phase()
      """,
      "DROP TRIGGER hm_phase_questions_notes_answer_phase_check ON holistic_mentorship_phase_questions"
    )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_protect_notes_audit()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Post-Session Notes mutation audits are immutable'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_protect_notes_audit()"
    )

    execute(
      """
      CREATE TRIGGER hm_post_session_note_audits_immutable
      BEFORE UPDATE OR DELETE ON holistic_mentorship_post_session_note_audits
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_protect_notes_audit()
      """,
      "DROP TRIGGER hm_post_session_note_audits_immutable ON holistic_mentorship_post_session_note_audits"
    )
  end
end
