defmodule Dbservice.Repo.Migrations.CreateBlendedLearningMentorFlags do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Mentor Flags
  # directly over SQL, so there is no schema/context/controller here. A Mentor raises at
  # most one flag per Flag Recipient on a Conversation. af_lms only inserts rows.
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
  end
end
