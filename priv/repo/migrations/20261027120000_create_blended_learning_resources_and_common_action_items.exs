defmodule Dbservice.Repo.Migrations.CreateBlendedLearningResourcesAndCommonActionItems do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of these tables directly over SQL, so
  # there is no schema/context/controller here. Blended Learning Admins manage both from
  # af_lms's Manage page.
  #
  # Resources are the Mentors' reading list on the Resources tab, ordered by position. Rows
  # are hard-deleted. The existing Mentor Toolkit doc is seeded so the tab keeps it;
  # created_by_email / updated_by_email are NULL only for that seeded row.
  #
  # A Common Action Item is pushed by an admin to a target (every Student with an active
  # Mapping, one grade, one Mentor's Students, or specific Students by their `student_id`,
  # kept in target_student_ids so a later push can reach them again) and materialised, at
  # push time, as one open Action Item per targeted Student: an Action Item now has exactly
  # one source, a Conversation, a Common Action Item or the Student's Profile Doc
  # (20261027100000 made conversation_id nullable for the Profile Doc). A Student gets a
  # Common Action Item at most once, so a repeated push only adds it to targeted Students
  # who don't have it yet.
  # Removing a Common Action Item soft-removes it (removed_at / removed_by_email); af_lms
  # deletes its still-open Action Items and keeps the done ones as history.

  @resources :blended_learning_resources
  @common :blended_learning_common_action_items
  @action_items :blended_learning_action_items

  @mentor_toolkit_url "https://docs.google.com/document/d/1kST-wRFTWgczw7SqBAxW97KNyJ0fzuBoOBsIelTQ8W0/edit?usp=sharing"

  def change do
    create table(@resources) do
      add :title, :string, size: 200, null: false
      add :url, :text, null: false
      add :position, :integer, null: false
      add :created_by_email, :string, size: 255
      add :updated_by_email, :string, size: 255

      timestamps(default: fragment("now()"), null: false)
    end

    create constraint(@resources, :bl_resources_title_check, check: "title ~ '[^[:space:]]'")

    create constraint(@resources, :bl_resources_url_check,
             check: "url ~ '^https://[^[:space:]]+$'"
           )

    create constraint(@resources, :bl_resources_position_check, check: "position >= 1")

    create constraint(@resources, :bl_resources_created_by_email_check,
             check: "created_by_email IS NULL OR created_by_email ~ '[^[:space:]]'"
           )

    create constraint(@resources, :bl_resources_updated_by_email_check,
             check: "updated_by_email IS NULL OR updated_by_email ~ '[^[:space:]]'"
           )

    execute(
      """
      INSERT INTO blended_learning_resources (title, url, position)
      VALUES ('Mentor Toolkit: Supporting Students Through Non-Academic Stress', '#{@mentor_toolkit_url}', 1)
      """,
      "DELETE FROM blended_learning_resources"
    )

    create table(@common) do
      add :text, :text, null: false
      add :owner, :string, null: false
      add :target_kind, :string, null: false
      add :target_grade, :integer
      add :target_mentor_user_id, references(:user, on_delete: :nothing)
      add :created_by_email, :string, size: 255, null: false
      add :removed_at, :utc_datetime
      add :removed_by_email, :string, size: 255

      timestamps(default: fragment("now()"), null: false)

      # `student.student_id` values (sheet/program IDs, leading zeros kept) for the
      # `students` target.
      add :target_student_ids, {:array, :text}
    end

    create constraint(@common, :bl_common_action_items_text_check,
             check: "text ~ '[^[:space:]]' AND char_length(text) <= 500"
           )

    create constraint(@common, :bl_common_action_items_owner_check,
             check: "owner IN ('student', 'mentor', 'parent')"
           )

    create constraint(@common, :bl_common_action_items_target_check,
             check: """
             (
               target_kind = 'all'
               AND target_grade IS NULL
               AND target_mentor_user_id IS NULL
               AND target_student_ids IS NULL
             )
             OR (
               target_kind = 'grade'
               AND target_grade IS NOT NULL
               AND target_grade IN (12, 13)
               AND target_mentor_user_id IS NULL
               AND target_student_ids IS NULL
             )
             OR (
               target_kind = 'mentor'
               AND target_grade IS NULL
               AND target_mentor_user_id IS NOT NULL
               AND target_student_ids IS NULL
             )
             OR (
               target_kind = 'students'
               AND target_grade IS NULL
               AND target_mentor_user_id IS NULL
               AND target_student_ids IS NOT NULL
               AND cardinality(target_student_ids) >= 1
               AND array_position(target_student_ids, NULL) IS NULL
             )
             """
           )

    create constraint(@common, :bl_common_action_items_created_by_email_check,
             check: "created_by_email ~ '[^[:space:]]'"
           )

    create constraint(@common, :bl_common_action_items_removal_check,
             check: """
             (removed_at IS NULL AND removed_by_email IS NULL)
             OR (
               removed_at IS NOT NULL
               AND removed_by_email IS NOT NULL
               AND removed_by_email ~ '[^[:space:]]'
             )
             """
           )

    # A pushed Action Item has no Conversation, like a Profile Doc one; the
    # (conversation_id, student_id) FK is not checked while conversation_id is NULL.
    alter table(@action_items) do
      add :common_action_item_id, references(@common, on_delete: :nothing)
    end

    # Replaces 20261027100000's two-source check. Rolling back deletes the pushed Action
    # Items, then restores it.
    execute(&three_source_check/0, &restore_two_source_check/0)

    create unique_index(@action_items, [:common_action_item_id, :student_id],
             name: :bl_action_items_common_student_unique,
             where: "common_action_item_id IS NOT NULL"
           )
  end

  defp three_source_check do
    replace_source_check("""
    (conversation_id IS NOT NULL)::integer
      + (common_action_item_id IS NOT NULL)::integer
      + from_profile_doc::integer = 1
    """)
  end

  defp restore_two_source_check do
    repo().query!(
      "DELETE FROM blended_learning_action_items WHERE common_action_item_id IS NOT NULL"
    )

    replace_source_check("(conversation_id IS NOT NULL) <> from_profile_doc")
  end

  defp replace_source_check(check) do
    repo().query!(
      "ALTER TABLE blended_learning_action_items DROP CONSTRAINT bl_action_items_source_check"
    )

    repo().query!(
      "ALTER TABLE blended_learning_action_items ADD CONSTRAINT bl_action_items_source_check CHECK (#{check})"
    )
  end
end
