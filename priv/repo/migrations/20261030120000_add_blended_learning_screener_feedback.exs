defmodule Dbservice.Repo.Migrations.AddBlendedLearningScreenerFeedback do
  use Ecto.Migration

  # LMS-owned, like the rest of Blended Learning: af_lms reads and writes this column and
  # table directly over SQL, so there is no schema/context/controller here.
  #
  # - blended_learning_conversations.screener_used: the Mentor's answer to "Was the
  #   screener form used?" on a Conversation. NULL when the Student had no Screener link
  #   when it was logged, and always NULL on an Attempt. Conversations are append-only
  #   (bl_conversations_immutable), so af_lms sets it in the INSERT; adding the nullable
  #   column touches no existing row.
  # - blended_learning_screener_feedback: the Mentor's two 1-5 ratings, asked once per
  #   Student, on the first Conversation that used the screener. Saved in the same
  #   transaction as that Conversation; the UNIQUE student_id turns a second, racing save
  #   into a conflict. A later Mentor of the same Student is not asked again. af_lms only
  #   inserts rows.

  @conversations :blended_learning_conversations
  @feedback :blended_learning_screener_feedback

  def change do
    alter table(@conversations) do
      add :screener_used, :boolean,
        comment:
          "Was the screener form used? NULL when the Student had no Screener link, " <>
            "and on an Attempt"
    end

    create constraint(@conversations, :bl_conversations_screener_used_check,
             check: "screener_used IS NULL OR kind = 'conversation'"
           )

    create table(@feedback) do
      add :student_id, references(:student, on_delete: :nothing), null: false

      add :conversation_id,
          references(@conversations, with: [student_id: :student_id], on_delete: :nothing),
          null: false

      add :mentor_user_id, references(:user, on_delete: :nothing), null: false
      add :helped_understand, :smallint, null: false
      add :more_comfortable, :smallint, null: false

      timestamps(default: fragment("now()"), null: false, updated_at: false)
    end

    create unique_index(@feedback, [:student_id], name: :bl_screener_feedback_student_unique)

    create constraint(@feedback, :bl_screener_feedback_helped_understand_check,
             check: "helped_understand BETWEEN 1 AND 5"
           )

    create constraint(@feedback, :bl_screener_feedback_more_comfortable_check,
             check: "more_comfortable BETWEEN 1 AND 5"
           )
  end
end
