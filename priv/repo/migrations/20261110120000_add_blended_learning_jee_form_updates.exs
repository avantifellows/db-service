defmodule Dbservice.Repo.Migrations.AddBlendedLearningJeeFormUpdates do
  use Ecto.Migration

  # LMS-owned, like the rest of Blended Learning: af_lms reads and writes these tables and
  # columns directly over SQL, so there is no schema/context/controller here.
  #
  # The JEE form card on a Blended Learning Student's page: a Mentor (or a Blended Learning
  # Admin) records whether the Student has filled the form for one exam sitting (JEE Main
  # 2027 first; exam_id + exam_year name it). Each save is a new row, so the latest row per
  # (student_id, exam_id, exam_year) is the current status and the earlier ones are its
  # history. Rows are append-only (bl_jee_form_updates_immutable).
  #
  # - filled: the application number (also upserted by af_lms into student_exam_record
  #   through the DB Service) and, optionally, the confirmation page uploaded as an
  #   lms_student_documents row. Never a password: application_password stays on
  #   student_exam_record only.
  # - not_filled: one or more reasons (fixed codes; af_lms holds the labels) and optional
  #   details, which are required when 'other' is a reason. A not_filled row raises a
  #   Mentor Flag for the program team (recipient 'jee_form', below).
  #
  # blended_learning_mentor_flags: a flag now comes from a Conversation (as before) or from
  # a not_filled JEE form update, never both, and only the JEE form raises 'jee_form'. The
  # (jee_form_update_id, student_id) FK keeps it on the same Student.
  #
  # blended_learning_action_items: a done Action Item is now completed by a Conversation or
  # by a filled JEE form update (af_lms ticks the Student's open "JEE Form Filling
  # (Reminder)" Common Action Item when the form is recorded as filled), never both.
  #
  # Rolling back deletes the JEE form flags and reopens the Action Items a JEE form ticked
  # before restoring the earlier checks.

  @updates :blended_learning_jee_form_updates
  @flags :blended_learning_mentor_flags
  @action_items :blended_learning_action_items

  @reasons ~w(
    certificate_not_available
    document_issue
    form_difficulty
    awaiting_parent_salary
    personal_issues
    not_interested
    not_prepared
    phase_two
    not_sharing_details
    not_aware
    other
  )

  def change do
    create table(@updates) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :exam_id, references(:exam, on_delete: :nothing), null: false
      add :exam_year, :integer, null: false
      add :status, :string, null: false
      add :application_number, :string, size: 255

      add :confirmation_document_id,
          references(:lms_student_documents, on_delete: :nothing)

      add :reasons, {:array, :string}
      add :details, :text
      # The Student's active Mapping when the update was recorded, as on a Conversation.
      add :mentor_user_id, references(:user, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :academic_year, :string, null: false
      add :recorded_by_email, :string, size: 255, null: false

      timestamps(default: fragment("now()"), null: false, updated_at: false)
    end

    create index(@updates, [:student_id, :exam_id, :exam_year, "id DESC"],
             name: :bl_jee_form_updates_student_exam_idx
           )

    create unique_index(@updates, [:id, :student_id],
             name: :bl_jee_form_updates_id_student_unique
           )

    create constraint(@updates, :bl_jee_form_updates_status_check,
             check: "status IN ('filled', 'not_filled')"
           )

    create constraint(@updates, :bl_jee_form_updates_exam_year_check,
             check: "exam_year BETWEEN 2000 AND 2100"
           )

    create constraint(@updates, :bl_jee_form_updates_status_fields_check,
             check: """
             (
               status = 'filled'
               AND application_number IS NOT NULL
               AND application_number ~ '[^[:space:]]'
               AND reasons IS NULL
               AND details IS NULL
             )
             OR (
               status = 'not_filled'
               AND application_number IS NULL
               AND confirmation_document_id IS NULL
               AND reasons IS NOT NULL
               AND cardinality(reasons) >= 1
               AND array_position(reasons, NULL) IS NULL
               AND reasons <@ ARRAY[#{reason_list()}]::varchar[]
               AND (NOT ('other' = ANY(reasons)) OR details IS NOT NULL)
             )
             """
           )

    create constraint(@updates, :bl_jee_form_updates_details_check,
             check:
               "details IS NULL OR (details ~ '[^[:space:]]' AND char_length(details) <= 2000)"
           )

    create constraint(@updates, :bl_jee_form_updates_academic_year_check,
             check: "academic_year ~ '[^[:space:]]'"
           )

    create constraint(@updates, :bl_jee_form_updates_recorded_by_email_check,
             check: "recorded_by_email ~ '[^[:space:]]'"
           )

    execute(
      """
      CREATE FUNCTION blended_learning_protect_jee_form_update()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Blended Learning JEE form updates are append-only'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION blended_learning_protect_jee_form_update()"
    )

    execute(
      """
      CREATE TRIGGER bl_jee_form_updates_immutable
      BEFORE UPDATE OR DELETE ON blended_learning_jee_form_updates
      FOR EACH ROW EXECUTE FUNCTION blended_learning_protect_jee_form_update()
      """,
      "DROP TRIGGER bl_jee_form_updates_immutable ON blended_learning_jee_form_updates"
    )

    # Mentor Flags from a JEE form update have no Conversation.
    alter table(@flags) do
      add :jee_form_update_id,
          references(@updates, with: [student_id: :student_id], on_delete: :nothing)
    end

    create unique_index(@flags, [:jee_form_update_id],
             name: :bl_mentor_flags_jee_form_update_unique,
             where: "jee_form_update_id IS NOT NULL"
           )

    execute(&flags_from_jee_form/0, &flags_from_conversations_only/0)

    # Action Items completed by a filled JEE form update.
    alter table(@action_items) do
      add :completed_by_jee_form_update_id,
          references(@updates, with: [student_id: :student_id], on_delete: :nothing)
    end

    execute(&completion_by_jee_form/0, &completion_by_conversation_only/0)
  end

  defp reason_list, do: Enum.map_join(@reasons, ", ", &"'#{&1}'")

  defp flags_from_jee_form do
    repo().query!(
      "ALTER TABLE blended_learning_mentor_flags ALTER COLUMN conversation_id DROP NOT NULL"
    )

    replace_flag_recipient_check(
      "recipient IN ('emotional_wellbeing', 'physics', 'chemistry', 'maths', 'jee_form')"
    )

    repo().query!("""
    ALTER TABLE blended_learning_mentor_flags ADD CONSTRAINT bl_mentor_flags_source_check CHECK (
      (conversation_id IS NOT NULL AND jee_form_update_id IS NULL AND recipient <> 'jee_form')
      OR (conversation_id IS NULL AND jee_form_update_id IS NOT NULL AND recipient = 'jee_form')
    )
    """)
  end

  defp flags_from_conversations_only do
    repo().query!(
      "DELETE FROM blended_learning_mentor_flags WHERE jee_form_update_id IS NOT NULL"
    )

    repo().query!(
      "ALTER TABLE blended_learning_mentor_flags DROP CONSTRAINT bl_mentor_flags_source_check"
    )

    replace_flag_recipient_check(
      "recipient IN ('emotional_wellbeing', 'physics', 'chemistry', 'maths')"
    )

    repo().query!(
      "ALTER TABLE blended_learning_mentor_flags ALTER COLUMN conversation_id SET NOT NULL"
    )
  end

  defp replace_flag_recipient_check(check) do
    repo().query!(
      "ALTER TABLE blended_learning_mentor_flags DROP CONSTRAINT bl_mentor_flags_recipient_check"
    )

    repo().query!(
      "ALTER TABLE blended_learning_mentor_flags ADD CONSTRAINT bl_mentor_flags_recipient_check CHECK (#{check})"
    )
  end

  defp completion_by_jee_form do
    replace_completion_check("""
    (
      status = 'open'
      AND completed_by_conversation_id IS NULL
      AND completed_by_jee_form_update_id IS NULL
      AND completed_at IS NULL
      AND completed_by_email IS NULL
    )
    OR (
      status <> 'open'
      AND (completed_by_conversation_id IS NOT NULL)
        <> (completed_by_jee_form_update_id IS NOT NULL)
      AND completed_at IS NOT NULL
      AND completed_by_email IS NOT NULL
    )
    """)
  end

  defp completion_by_conversation_only do
    repo().query!("""
    UPDATE blended_learning_action_items
    SET status = 'open', completed_by_jee_form_update_id = NULL, completed_at = NULL,
        completed_by_email = NULL, updated_at = now()
    WHERE completed_by_jee_form_update_id IS NOT NULL
    """)

    replace_completion_check("""
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
    """)
  end

  defp replace_completion_check(check) do
    repo().query!(
      "ALTER TABLE blended_learning_action_items DROP CONSTRAINT bl_action_items_completion_check"
    )

    repo().query!(
      "ALTER TABLE blended_learning_action_items ADD CONSTRAINT bl_action_items_completion_check CHECK (#{check})"
    )
  end
end
