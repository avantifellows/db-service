defmodule Dbservice.Repo.Migrations.AddLegacyConversationToBlendedLearningStudentLinks do
  use Ecto.Migration

  # LMS-owned, like the rest of Blended Learning Student Links: af_lms reads and writes
  # these columns directly over SQL, so there is no schema/context/controller here.
  #
  # legacy_conversation_summary and legacy_action_items are a snapshot of the latest dated
  # entry in the Student's legacy Google Profile Doc (the same entry that
  # legacy_last_contact_on dates), written by af_lms's re-runnable links importer. Mentors
  # see it until they log the Student's first conversation in the app, which supersedes it
  # in the UI. Both are NULL when the doc has no usable entry.
  #
  # legacy_action_items is a JSON array of 1 to 10 `{"text": string, "owner":
  # "student" | "mentor" | "parent"}` objects; the importer validates element shape.
  # Action items never stand without a summary.

  @table :blended_learning_student_links

  def change do
    alter table(@table) do
      add :legacy_conversation_summary, :text,
        comment:
          "Summary of the latest Profile Doc entry (snapshot by af_lms links importer); " <>
            "superseded in the UI by the first app conversation"

      add :legacy_action_items, :map,
        comment:
          "Action items of the latest Profile Doc entry: JSON array of {text, owner} " <>
            "(snapshot by af_lms links importer); superseded by the first app conversation"
    end

    create constraint(@table, :bl_student_links_legacy_conversation_summary_check,
             check: """
             legacy_conversation_summary IS NULL
             OR (
               legacy_conversation_summary ~ '[^[:space:]]'
               AND char_length(legacy_conversation_summary) <= 2000
             )
             """
           )

    # CASE guarantees jsonb_array_length only runs on arrays (it raises on scalars/objects).
    create constraint(@table, :bl_student_links_legacy_action_items_check,
             check: """
             legacy_action_items IS NULL
             OR CASE
               WHEN jsonb_typeof(legacy_action_items) = 'array'
                 THEN jsonb_array_length(legacy_action_items) BETWEEN 1 AND 10
               ELSE false
             END
             """
           )

    create constraint(@table, :bl_student_links_legacy_action_items_need_summary_check,
             check: "legacy_action_items IS NULL OR legacy_conversation_summary IS NOT NULL"
           )
  end
end
