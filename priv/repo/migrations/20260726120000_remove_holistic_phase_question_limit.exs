defmodule Dbservice.Repo.Migrations.RemoveHolisticPhaseQuestionLimit do
  use Ecto.Migration

  @unlimited_count_function """
  CREATE OR REPLACE FUNCTION holistic_mentorship_validate_phase_question_count()
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

        IF question_count < 1 THEN
          RAISE EXCEPTION 'Holistic Mentorship Phase % must have at least one Question', OLD.phase_id
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

      IF question_count < 1 THEN
        RAISE EXCEPTION 'Holistic Mentorship Phase % must have at least one Question', target_phase_id
          USING ERRCODE = '23514';
      END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;

    RETURN NEW;
  END;
  $$;
  """

  @limited_count_function String.replace(
                            @unlimited_count_function,
                            "question_count < 1",
                            "question_count NOT BETWEEN 1 AND 4"
                          )
                          |> String.replace(
                            "must have at least one Question",
                            "must have one to four Questions"
                          )

  def up do
    execute("""
    ALTER TABLE holistic_mentorship_phase_questions
      DROP CONSTRAINT hm_phase_questions_position_check,
      ADD CONSTRAINT hm_phase_questions_position_check CHECK (position > 0)
    """)

    execute(@unlimited_count_function)
  end

  def down do
    execute(@limited_count_function)

    execute("""
    ALTER TABLE holistic_mentorship_phase_questions
      DROP CONSTRAINT hm_phase_questions_position_check,
      ADD CONSTRAINT hm_phase_questions_position_check CHECK (position BETWEEN 1 AND 4)
    """)
  end
end
