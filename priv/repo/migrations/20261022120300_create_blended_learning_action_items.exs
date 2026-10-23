defmodule Dbservice.Repo.Migrations.CreateBlendedLearningActionItems do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Action Items
  # directly over SQL, so there is no schema/context/controller here. An Action Item is
  # created on a Conversation and may change only once, from open to done, by linking the
  # later Conversation that closed it. Open to done is enforced by af_lms and
  # `bl_action_items_completion_check`.
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
  end
end
