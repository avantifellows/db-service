defmodule Dbservice.Repo.Migrations.CreateBlendedLearningActionItems do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Action Items
  # directly over SQL, so there is no schema/context/controller here. An Action Item is
  # created on a Conversation and may change only once, from open to done, by linking the
  # later Conversation that closed it.
  #
  # Blended Learning migration 4 of 8.

  @table :blended_learning_action_items
  @conversations :blended_learning_conversations

  def change do
    create table(@table) do
      add :conversation_id,
          references(@conversations, with: [student_id: :student_id], on_delete: :nothing),
          null: false

      add :student_id, references(:student, on_delete: :nothing), null: false
      add :position, :integer, null: false
      add :text, :text, null: false
      add :owner, :string, null: false
      add :due_on, :date
      add :status, :string, null: false, default: "open"

      add :completed_by_conversation_id,
          references(@conversations, with: [student_id: :student_id], on_delete: :nothing)

      add :completed_at, :utc_datetime
      add :completed_by_email, :string, size: 255

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(@table, [:conversation_id, :position],
             name: :bl_action_items_conversation_position_unique
           )

    create index(@table, [:student_id],
             name: :bl_action_items_open_student_idx,
             where: "status = 'open'"
           )

    create constraint(@table, :bl_action_items_position_check, check: "position >= 1")
    create constraint(@table, :bl_action_items_text_check, check: "text ~ '[^[:space:]]'")

    create constraint(@table, :bl_action_items_owner_check,
             check: "owner IN ('student', 'mentor', 'parent')"
           )

    create constraint(@table, :bl_action_items_status_check, check: "status IN ('open', 'done')")

    create constraint(@table, :bl_action_items_completed_by_email_check,
             check: "completed_by_email IS NULL OR completed_by_email ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_action_items_completion_check,
             check: """
             (
               status = 'open'
               AND completed_by_conversation_id IS NULL
               AND completed_at IS NULL
               AND completed_by_email IS NULL
             )
             OR (
               status <> 'open'
               AND completed_by_conversation_id IS NOT NULL
               AND completed_at IS NOT NULL
               AND completed_by_email IS NOT NULL
             )
             """
           )

    execute(
      """
      CREATE FUNCTION blended_learning_protect_action_item()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'UPDATE'
          AND OLD.status = 'open'
          AND NEW.status = 'done'
          AND (
            NEW.id,
            NEW.conversation_id,
            NEW.student_id,
            NEW.position,
            NEW.text,
            NEW.owner,
            NEW.due_on,
            NEW.inserted_at
          ) IS NOT DISTINCT FROM (
            OLD.id,
            OLD.conversation_id,
            OLD.student_id,
            OLD.position,
            OLD.text,
            OLD.owner,
            OLD.due_on,
            OLD.inserted_at
          )
        THEN
          RETURN NEW;
        END IF;

        RAISE EXCEPTION 'Blended Learning Action Items may change only from open to done'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION blended_learning_protect_action_item()"
    )

    execute(
      """
      CREATE TRIGGER bl_action_items_immutable
      BEFORE UPDATE OR DELETE ON blended_learning_action_items
      FOR EACH ROW EXECUTE FUNCTION blended_learning_protect_action_item()
      """,
      "DROP TRIGGER bl_action_items_immutable ON blended_learning_action_items"
    )

    execute(
      """
      CREATE TRIGGER bl_action_items_conversation_kind
      BEFORE INSERT OR UPDATE ON blended_learning_action_items
      FOR EACH ROW EXECUTE FUNCTION
        blended_learning_reject_attempt_reference('conversation_id', 'completed_by_conversation_id')
      """,
      "DROP TRIGGER bl_action_items_conversation_kind ON blended_learning_action_items"
    )
  end
end
