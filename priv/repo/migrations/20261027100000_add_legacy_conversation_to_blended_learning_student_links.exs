defmodule Dbservice.Repo.Migrations.AddLegacyConversationToBlendedLearningStudentLinks do
  use Ecto.Migration

  # LMS-owned, like the rest of Blended Learning: af_lms reads and writes these columns
  # and rows directly over SQL, so there is no schema/context/controller here.
  #
  # The latest dated entry in the Student's legacy Google Profile Doc (the same entry that
  # legacy_last_contact_on dates), loaded by af_lms's re-runnable links importer:
  #
  # - legacy_conversation_summary: its summary, shown in the Student's conversation
  #   history at legacy_last_contact_on. NULL when the doc has no usable entry. It is not
  #   a Conversation and is never counted as one.
  # - its action items become ordinary Blended Learning Action Items with
  #   from_profile_doc = true and no Conversation, positioned 1..n in the doc's order.
  #   They are ticked done like any other, by the later Conversation that closes them. A
  #   re-import keeps the ones whose text and owner still match, inserts new ones open and
  #   deletes only open ones no longer in the doc; at most one per (student, text, owner).
  #
  # An Action Item now comes from exactly one Conversation or the Profile Doc. The
  # (conversation_id, student_id) FK is not checked while conversation_id is NULL. Rolling
  # back deletes the Profile Doc Action Items before restoring NOT NULL.

  @links :blended_learning_student_links
  @action_items :blended_learning_action_items

  def change do
    alter table(@links) do
      add :legacy_conversation_summary, :text,
        comment:
          "Summary of the latest Profile Doc entry (af_lms links importer), shown in the " <>
            "conversation history at legacy_last_contact_on"
    end

    create constraint(@links, :bl_student_links_legacy_conversation_summary_check,
             check: """
             legacy_conversation_summary IS NULL
             OR (
               legacy_conversation_summary ~ '[^[:space:]]'
               AND char_length(legacy_conversation_summary) <= 2000
             )
             """
           )

    alter table(@action_items) do
      add :from_profile_doc, :boolean,
        null: false,
        default: false,
        comment:
          "Loaded from the latest Profile Doc entry by the af_lms links importer; " <>
            "such an Action Item has no Conversation"
    end

    execute(
      "ALTER TABLE blended_learning_action_items ALTER COLUMN conversation_id DROP NOT NULL",
      &restore_conversation_id_not_null/0
    )

    create constraint(@action_items, :bl_action_items_source_check,
             check: "(conversation_id IS NOT NULL) <> from_profile_doc"
           )

    create unique_index(@action_items, [:student_id, :text, :owner],
             name: :bl_action_items_profile_doc_unique,
             where: "from_profile_doc"
           )
  end

  defp restore_conversation_id_not_null do
    repo().query!("DELETE FROM blended_learning_action_items WHERE from_profile_doc")

    repo().query!(
      "ALTER TABLE blended_learning_action_items ALTER COLUMN conversation_id SET NOT NULL"
    )
  end
end
