defmodule Dbservice.Repo.Migrations.CreateBlendedLearningConversationDrafts do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Conversation Drafts
  # directly over SQL, so there is no schema/context/controller here. etl-next fills the
  # drafted content only through the db-service machine API. The table is mutable; af_lms
  # owns state transitions, so there is no state-transition trigger.
  #
  # `saved_conversation_id` is added by the next migration, which creates
  # blended_learning_conversations and closes the draft <-> conversation FK cycle.
  #
  # Blended Learning migration 2 of 8.

  @table :blended_learning_conversation_drafts

  def change do
    create table(@table) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :academic_year, :string, null: false
      add :mentor_user_id, references(:user, on_delete: :nothing), null: false
      add :created_by_user_id, references(:user, on_delete: :nothing)
      add :created_by_email, :string, size: 255, null: false
      add :state, :string, null: false
      add :occurred_on, :date
      add :mode, :string
      add :spoke_with, :string
      add :duration_minutes, :integer
      add :call_recording_s3_key, :text, null: false
      add :recording_content_type, :string, null: false
      add :recording_byte_size, :bigint, null: false
      add :transcript_s3_key, :text
      add :draft_summary, :text
      add :draft_summary_tags, {:array, :text}
      add :draft_action_items, :jsonb
      add :draft_notes, :jsonb
      add :draft_items_to_verify, :jsonb
      add :detected_language, :string
      add :prompt_version, :string
      add :model_id, :string
      add :ready_at, :utc_datetime
      add :discarded_at, :utc_datetime

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(@table, [:id, :student_id],
             name: :bl_conversation_drafts_id_student_unique
           )

    create unique_index(@table, [:student_id],
             name: :bl_conversation_drafts_open_student_unique,
             where: "state IN ('transcribing', 'ready', 'failed')"
           )

    create constraint(@table, :bl_conversation_drafts_academic_year_check,
             check: "academic_year ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_conversation_drafts_created_by_email_check,
             check: "created_by_email ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_conversation_drafts_mode_check,
             check: "mode IS NULL OR mode IN ('call', 'in_person')"
           )

    create constraint(@table, :bl_conversation_drafts_spoke_with_check,
             check: "spoke_with IS NULL OR spoke_with IN ('student', 'parent_or_sibling', 'both')"
           )

    create constraint(@table, :bl_conversation_drafts_duration_minutes_check,
             check: "duration_minutes IS NULL OR duration_minutes BETWEEN 1 AND 240"
           )

    create constraint(@table, :bl_conversation_drafts_call_recording_s3_key_check,
             check: "call_recording_s3_key ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_conversation_drafts_recording_content_type_check,
             check: "recording_content_type ~ '^audio/'"
           )

    create constraint(@table, :bl_conversation_drafts_recording_byte_size_check,
             check: "recording_byte_size > 0"
           )

    create constraint(@table, :bl_conversation_drafts_draft_summary_tags_check,
             check: "draft_summary_tags IS NULL OR cardinality(draft_summary_tags) <= 4"
           )

    create constraint(@table, :bl_conversation_drafts_draft_action_items_check,
             check: "draft_action_items IS NULL OR jsonb_typeof(draft_action_items) = 'array'"
           )

    create constraint(@table, :bl_conversation_drafts_draft_notes_check,
             check: "draft_notes IS NULL OR jsonb_typeof(draft_notes) = 'array'"
           )

    create constraint(@table, :bl_conversation_drafts_draft_items_to_verify_check,
             check:
               "draft_items_to_verify IS NULL OR jsonb_typeof(draft_items_to_verify) = 'array'"
           )

    create constraint(@table, :bl_conversation_drafts_state_check,
             check: "state IN ('transcribing', 'ready', 'failed', 'discarded', 'saved')"
           )

    # State CHECKs are one-way implications; the `saved` one is added with
    # saved_conversation_id in the next migration.
    create constraint(@table, :bl_conversation_drafts_ready_check,
             check: """
             state <> 'ready'
             OR (
               draft_summary IS NOT NULL
               AND draft_summary ~ '[^[:space:]]'
               AND transcript_s3_key IS NOT NULL
               AND prompt_version IS NOT NULL
               AND model_id IS NOT NULL
               AND ready_at IS NOT NULL
             )
             """
           )

    create constraint(@table, :bl_conversation_drafts_discarded_check,
             check: "state <> 'discarded' OR discarded_at IS NOT NULL"
           )
  end
end
