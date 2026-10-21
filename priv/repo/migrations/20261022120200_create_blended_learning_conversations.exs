defmodule Dbservice.Repo.Migrations.CreateBlendedLearningConversations do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Conversations and
  # Attempts directly over SQL, so there is no schema/context/controller here. An Attempt
  # is a row of kind `attempt`. Rows are append-only.
  #
  # This migration also adds blended_learning_conversation_drafts.saved_conversation_id,
  # closing the draft <-> conversation FK cycle.
  #
  # Blended Learning migration 3 of 8.

  @table :blended_learning_conversations
  @drafts :blended_learning_conversation_drafts

  def change do
    create table(@table) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :academic_year, :string, null: false
      add :mentor_user_id, references(:user, on_delete: :nothing), null: false
      add :logged_by_user_id, references(:user, on_delete: :nothing)
      add :logged_by_email, :string, size: 255, null: false
      add :kind, :string, null: false
      add :occurred_on, :date, null: false
      add :mode, :string
      add :spoke_with, :string
      add :duration_minutes, :integer
      add :summary, :text
      add :notes_html, :text
      add :attempt_note, :text
      add :call_recording_s3_key, :text
      add :transcript_s3_key, :text

      add :source_draft_id,
          references(@drafts, with: [student_id: :student_id], on_delete: :nothing)

      timestamps(default: fragment("now()"), null: false, updated_at: false)
    end

    create index(@table, [:student_id, "occurred_on DESC", "id DESC"],
             name: :bl_conversations_student_timeline_idx
           )

    create index(@table, [:mentor_user_id, :academic_year],
             name: :bl_conversations_mentor_year_idx
           )

    create unique_index(@table, [:id, :student_id], name: :bl_conversations_id_student_unique)

    create unique_index(@table, [:source_draft_id],
             name: :bl_conversations_source_draft_unique,
             where: "source_draft_id IS NOT NULL"
           )

    create constraint(@table, :bl_conversations_academic_year_check,
             check: "academic_year ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_conversations_logged_by_email_check,
             check: "logged_by_email ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_conversations_call_recording_s3_key_check,
             check: "call_recording_s3_key IS NULL OR call_recording_s3_key ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_conversations_transcript_s3_key_check,
             check: "transcript_s3_key IS NULL OR transcript_s3_key ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_conversations_kind_check,
             check: "kind IN ('conversation', 'attempt')"
           )

    create constraint(@table, :bl_conversations_mode_check,
             check: "mode IS NULL OR mode IN ('call', 'in_person')"
           )

    create constraint(@table, :bl_conversations_spoke_with_check,
             check: "spoke_with IS NULL OR spoke_with IN ('student', 'parent_or_sibling', 'both')"
           )

    create constraint(@table, :bl_conversations_duration_minutes_check,
             check: "duration_minutes IS NULL OR duration_minutes BETWEEN 1 AND 240"
           )

    create constraint(@table, :bl_conversations_kind_fields_check,
             check: """
             (
               kind = 'conversation'
               AND mode IS NOT NULL
               AND spoke_with IS NOT NULL
               AND duration_minutes IS NOT NULL
               AND summary IS NOT NULL
               AND summary ~ '[^[:space:]]'
               AND attempt_note IS NULL
             )
             OR (
               kind = 'attempt'
               AND mode IS NULL
               AND spoke_with IS NULL
               AND duration_minutes IS NULL
               AND summary IS NULL
               AND notes_html IS NULL
               AND call_recording_s3_key IS NULL
               AND transcript_s3_key IS NULL
               AND source_draft_id IS NULL
             )
             """
           )

    create constraint(@table, :bl_conversations_attempt_note_check,
             check: "attempt_note IS NULL OR attempt_note ~ '[^[:space:]]'"
           )

    execute(
      """
      CREATE FUNCTION blended_learning_protect_conversation()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Blended Learning Conversations and Attempts are append-only'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION blended_learning_protect_conversation()"
    )

    execute(
      """
      CREATE TRIGGER bl_conversations_immutable
      BEFORE UPDATE OR DELETE ON blended_learning_conversations
      FOR EACH ROW EXECUTE FUNCTION blended_learning_protect_conversation()
      """,
      "DROP TRIGGER bl_conversations_immutable ON blended_learning_conversations"
    )

    alter table(@drafts) do
      add :saved_conversation_id,
          references(@table, with: [student_id: :student_id], on_delete: :nothing)
    end

    create constraint(@drafts, :bl_conversation_drafts_saved_check,
             check: "state <> 'saved' OR saved_conversation_id IS NOT NULL"
           )

    # Shared kind rule for records attached to a Conversation (Action Items, Photos and
    # Mentor Flags): they may reference only kind `conversation`, never `attempt`.
    #
    # Calling convention: attach as a BEFORE INSERT OR UPDATE ... FOR EACH ROW trigger and
    # pass the name of each bigint column that references blended_learning_conversations(id)
    # as a trigger argument. NULL references are skipped; a reference to an `attempt`
    # raises SQLSTATE 23514. At least one argument is required. For example:
    #
    #   CREATE TRIGGER bl_action_items_conversation_kind
    #   BEFORE INSERT OR UPDATE ON blended_learning_action_items
    #   FOR EACH ROW EXECUTE FUNCTION
    #     blended_learning_reject_attempt_reference('conversation_id', 'completed_by_conversation_id')
    execute(
      """
      CREATE FUNCTION blended_learning_reject_attempt_reference()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        reference_column text;
        referenced_id bigint;
      BEGIN
        IF TG_NARGS = 0 THEN
          RAISE EXCEPTION 'blended_learning_reject_attempt_reference needs at least one column name';
        END IF;

        FOR argument_index IN 0 .. TG_NARGS - 1 LOOP
          reference_column := TG_ARGV[argument_index];
          EXECUTE format('SELECT ($1).%I::bigint', reference_column) INTO referenced_id USING NEW;

          IF referenced_id IS NOT NULL AND EXISTS (
            SELECT 1
            FROM blended_learning_conversations
            WHERE id = referenced_id AND kind = 'attempt'
          ) THEN
            RAISE EXCEPTION '% must reference a Blended Learning Conversation, not an Attempt',
              reference_column
              USING ERRCODE = '23514';
          END IF;
        END LOOP;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION blended_learning_reject_attempt_reference()"
    )
  end
end
