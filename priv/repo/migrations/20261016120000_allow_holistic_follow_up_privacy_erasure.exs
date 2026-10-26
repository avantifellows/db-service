defmodule Dbservice.Repo.Migrations.AllowHolisticFollowUpPrivacyErasure do
  use Ecto.Migration

  def up do
    create table(:holistic_mentorship_follow_up_erasures) do
      add :privacy_deletion_id,
          references(:holistic_mentorship_privacy_deletions, on_delete: :nothing),
          null: false

      add :actor_user_id, references(:user, on_delete: :nothing), null: false
      add :reason, :text, null: false
      add :answers_erased, :integer, null: false
      add :occurred_at, :utc_datetime, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:holistic_mentorship_follow_up_erasures, [:privacy_deletion_id],
             name: :hm_follow_up_erasures_privacy_deletion_uidx
           )

    create constraint(
             :holistic_mentorship_follow_up_erasures,
             :hm_follow_up_erasures_content_check,
             check: "reason ~ '[^[:space:]]' AND answers_erased > 0"
           )

    execute("""
    CREATE TRIGGER hm_follow_up_erasures_immutable
    BEFORE UPDATE OR DELETE ON holistic_mentorship_follow_up_erasures
    FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_protect_privacy_deletion()
    """)

    execute("""
    CREATE OR REPLACE FUNCTION holistic_mentorship_protect_follow_up_note()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
      erased_marker constant text := 'Content erased under approved privacy request';
      answer_columns constant text[] := ARRAY[
        'challenges_answer', 'solutions_answer', 'action_plan_answer'
      ];
    BEGIN
      IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Follow-up Notes are immutable' USING ERRCODE = '23514';
      END IF;

      -- Callers take this lock before row locks, matching all other content writers.
      PERFORM pg_advisory_xact_lock(OLD.student_id::integer, 0);

      IF NOT EXISTS (
        SELECT 1 FROM holistic_mentorship_privacy_deletions deletion
        WHERE deletion.student_id = OLD.student_id
      ) OR (to_jsonb(NEW) - answer_columns) IS DISTINCT FROM
           (to_jsonb(OLD) - answer_columns)
        OR NEW.challenges_answer IS DISTINCT FROM
           (CASE WHEN OLD.challenges_answer IS NULL THEN NULL ELSE erased_marker END)
        OR NEW.solutions_answer IS DISTINCT FROM
           (CASE WHEN OLD.solutions_answer IS NULL THEN NULL ELSE erased_marker END)
        OR NEW.action_plan_answer IS DISTINCT FROM
           (CASE WHEN OLD.action_plan_answer IS NULL THEN NULL ELSE erased_marker END)
        OR NEW IS NOT DISTINCT FROM OLD
      THEN
        RAISE EXCEPTION 'Follow-up Notes only allow approved privacy erasure'
          USING ERRCODE = '23514';
      END IF;

      RETURN NEW;
    END;
    $$;
    """)
  end

  def down do
    execute("""
    CREATE OR REPLACE FUNCTION holistic_mentorship_protect_follow_up_note()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'Follow-up Notes are immutable' USING ERRCODE = '23514';
    END;
    $$;
    """)

    # Schema rollback cannot restore erased answers and discards the new audit history.
    drop table(:holistic_mentorship_follow_up_erasures)
  end
end
