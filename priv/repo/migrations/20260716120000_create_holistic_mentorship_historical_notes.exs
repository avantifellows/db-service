defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipHistoricalNotes do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_historical_notes) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :mentor_user_id, references(:user, on_delete: :nothing)
      add :source_system, :string, null: false
      add :source_record_key, :string, null: false
      add :source_fingerprint, :string, null: false
      add :imported_by_user_id, references(:user, on_delete: :nothing), null: false
      add :imported_at, :utc_datetime, null: false
      add :reconciliation_metadata, :map, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create table(:holistic_mentorship_historical_note_answers) do
      add :historical_note_id,
          references(:holistic_mentorship_historical_notes, on_delete: :nothing),
          null: false

      add :position, :integer, null: false
      add :question, :text, null: false
      add :answer, :text

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:holistic_mentorship_historical_notes, [:student_id, :source_system],
             name: :hm_historical_notes_student_source_unique
           )

    create unique_index(
             :holistic_mentorship_historical_note_answers,
             [:historical_note_id, :position],
             name: :hm_historical_note_answers_note_position_unique
           )

    create constraint(
             :holistic_mentorship_historical_note_answers,
             :hm_historical_note_answers_position_check,
             check: "position BETWEEN 1 AND 4"
           )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_validate_historical_answer_count()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        target_note_id bigint;
        answer_count integer;
      BEGIN
        IF TG_TABLE_NAME = 'holistic_mentorship_historical_note_answers' THEN
          IF TG_OP = 'UPDATE'
            AND OLD.historical_note_id <> NEW.historical_note_id
            AND EXISTS (SELECT 1 FROM holistic_mentorship_historical_notes WHERE id = OLD.historical_note_id)
          THEN
            SELECT count(*) INTO answer_count
            FROM holistic_mentorship_historical_note_answers
            WHERE historical_note_id = OLD.historical_note_id;

            IF answer_count <> 4 THEN
              RAISE EXCEPTION 'Historical Notes must have exactly four source Questions'
                USING ERRCODE = '23514';
            END IF;
          END IF;
        END IF;

        IF TG_TABLE_NAME = 'holistic_mentorship_historical_notes' THEN
          target_note_id := NEW.id;
        ELSIF TG_OP = 'DELETE' THEN
          target_note_id := OLD.historical_note_id;
        ELSE
          target_note_id := NEW.historical_note_id;
        END IF;

        IF EXISTS (SELECT 1 FROM holistic_mentorship_historical_notes WHERE id = target_note_id) THEN
          SELECT count(*) INTO answer_count
          FROM holistic_mentorship_historical_note_answers
          WHERE historical_note_id = target_note_id;

          IF answer_count <> 4 THEN
            RAISE EXCEPTION 'Historical Notes must have exactly four source Questions'
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
      "DROP FUNCTION holistic_mentorship_validate_historical_answer_count()"
    )

    execute(
      """
      CREATE CONSTRAINT TRIGGER hm_historical_notes_answer_count
      AFTER INSERT OR UPDATE ON holistic_mentorship_historical_notes
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_historical_answer_count()
      """,
      "DROP TRIGGER hm_historical_notes_answer_count ON holistic_mentorship_historical_notes"
    )

    execute(
      """
      CREATE CONSTRAINT TRIGGER hm_historical_note_answers_count
      AFTER INSERT OR UPDATE OR DELETE ON holistic_mentorship_historical_note_answers
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_validate_historical_answer_count()
      """,
      "DROP TRIGGER hm_historical_note_answers_count ON holistic_mentorship_historical_note_answers"
    )
  end
end
