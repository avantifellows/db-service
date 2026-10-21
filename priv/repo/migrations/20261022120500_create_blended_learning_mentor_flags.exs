defmodule Dbservice.Repo.Migrations.CreateBlendedLearningMentorFlags do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Mentor Flags
  # directly over SQL, so there is no schema/context/controller here. A Mentor raises at
  # most one flag per Flag Recipient on a Conversation. Rows are append-only except that
  # the af_lms notifier may set `notification_sent_at` exactly once.
  #
  # Blended Learning migration 6 of 8.

  @table :blended_learning_mentor_flags
  @conversations :blended_learning_conversations

  def change do
    create table(@table) do
      add :conversation_id,
          references(@conversations, with: [student_id: :student_id], on_delete: :nothing),
          null: false

      add :student_id, references(:student, on_delete: :nothing), null: false
      add :recipient, :string, null: false
      add :comment, :text
      add :raised_by_email, :string, size: 255, null: false
      add :notification_sent_at, :utc_datetime

      timestamps(default: fragment("now()"), null: false, updated_at: false)
    end

    create unique_index(@table, [:conversation_id, :recipient],
             name: :bl_mentor_flags_conversation_recipient_unique
           )

    create index(@table, ["inserted_at DESC"], name: :bl_mentor_flags_inserted_at_idx)

    create constraint(@table, :bl_mentor_flags_recipient_check,
             check: "recipient IN ('emotional_wellbeing', 'physics', 'chemistry', 'maths')"
           )

    create constraint(@table, :bl_mentor_flags_comment_check,
             check: "comment IS NULL OR comment ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_mentor_flags_raised_by_email_check,
             check: "raised_by_email ~ '[^[:space:]]'"
           )

    execute(
      """
      CREATE FUNCTION blended_learning_protect_mentor_flag()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'UPDATE'
          AND OLD.notification_sent_at IS NULL
          AND NEW.notification_sent_at IS NOT NULL
          AND (
            NEW.id,
            NEW.conversation_id,
            NEW.student_id,
            NEW.recipient,
            NEW.comment,
            NEW.raised_by_email,
            NEW.inserted_at
          ) IS NOT DISTINCT FROM (
            OLD.id,
            OLD.conversation_id,
            OLD.student_id,
            OLD.recipient,
            OLD.comment,
            OLD.raised_by_email,
            OLD.inserted_at
          )
        THEN
          RETURN NEW;
        END IF;

        RAISE EXCEPTION 'Blended Learning Mentor Flags may change only by setting notification_sent_at once'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION blended_learning_protect_mentor_flag()"
    )

    execute(
      """
      CREATE TRIGGER bl_mentor_flags_immutable
      BEFORE UPDATE OR DELETE ON blended_learning_mentor_flags
      FOR EACH ROW EXECUTE FUNCTION blended_learning_protect_mentor_flag()
      """,
      "DROP TRIGGER bl_mentor_flags_immutable ON blended_learning_mentor_flags"
    )

    execute(
      """
      CREATE TRIGGER bl_mentor_flags_conversation_kind
      BEFORE INSERT OR UPDATE ON blended_learning_mentor_flags
      FOR EACH ROW EXECUTE FUNCTION blended_learning_reject_attempt_reference('conversation_id')
      """,
      "DROP TRIGGER bl_mentor_flags_conversation_kind ON blended_learning_mentor_flags"
    )
  end
end
