defmodule Dbservice.Repo.Migrations.AddHolisticMentorshipAuditSnapshots do
  use Ecto.Migration

  @mapping_table "holistic_mentorship_mentor_mentee_mappings"
  @note_audit_table "holistic_mentorship_post_session_note_audits"

  def up do
    alter table(@mapping_table) do
      add :assigned_by_email, :string, size: 255
      add :assignment_audit_reason, :string, size: 500
      add :ended_by_email, :string, size: 255
      add :end_audit_reason, :string, size: 500
    end

    execute("ALTER TABLE #{@mapping_table} DROP CONSTRAINT hm_mappings_lifecycle_check")

    create constraint(
             @mapping_table,
             :hm_mappings_lifecycle_check,
             check: """
             assignment_source <> '' AND
             (
               ended_at IS NULL AND ended_by_user_id IS NULL AND ended_by_email IS NULL AND
               end_source IS NULL AND end_reason IS NULL AND end_audit_reason IS NULL
               OR
               ended_at IS NOT NULL AND end_source IS NOT NULL AND end_source <> '' AND
               end_reason IS NOT NULL AND end_reason <> '' AND ended_at >= started_at
             )
             """
           )

    create constraint(
             @mapping_table,
             :hm_mappings_audit_fields_check,
             check: """
             (assigned_by_email IS NULL OR assigned_by_email ~ '[^[:space:]]') AND
             (assignment_audit_reason IS NULL OR assignment_audit_reason ~ '[^[:space:]]') AND
             (ended_by_email IS NULL OR ended_by_email ~ '[^[:space:]]') AND
             (end_audit_reason IS NULL OR end_audit_reason ~ '[^[:space:]]')
             """
           )

    alter table(@note_audit_table) do
      add :actor_email, :string, size: 255
    end

    execute("ALTER TABLE #{@note_audit_table} ALTER COLUMN actor_user_id DROP NOT NULL")
    execute("ALTER TABLE #{@note_audit_table} ALTER COLUMN reason TYPE varchar(500)")

    create constraint(
             @note_audit_table,
             :hm_post_session_note_audits_actor_email_check,
             check: "actor_email IS NULL OR actor_email ~ '[^[:space:]]'"
           )

    create constraint(
             @note_audit_table,
             :hm_post_session_note_audits_actor_identity_check,
             check: "actor_user_id IS NOT NULL OR coalesce(actor_email, '') ~ '[^[:space:]]'"
           )
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM #{@note_audit_table}
        WHERE actor_user_id IS NULL
      ) THEN
        RAISE EXCEPTION
          'Cannot down-migrate Holistic Note audits while email-only actors exist';
      END IF;
    END
    $$;
    """)

    drop constraint(
           @note_audit_table,
           :hm_post_session_note_audits_actor_identity_check
         )

    drop constraint(
           @note_audit_table,
           :hm_post_session_note_audits_actor_email_check
         )

    alter table(@note_audit_table) do
      remove :actor_email
    end

    execute("ALTER TABLE #{@note_audit_table} ALTER COLUMN actor_user_id SET NOT NULL")
    execute("ALTER TABLE #{@note_audit_table} ALTER COLUMN reason TYPE varchar(255)")

    drop constraint(@mapping_table, :hm_mappings_audit_fields_check)
    drop constraint(@mapping_table, :hm_mappings_lifecycle_check)

    alter table(@mapping_table) do
      remove :end_audit_reason
      remove :ended_by_email
      remove :assignment_audit_reason
      remove :assigned_by_email
    end

    create constraint(
             @mapping_table,
             :hm_mappings_lifecycle_check,
             check: """
             assignment_source <> '' AND (
               (ended_at IS NULL AND ended_by_user_id IS NULL AND end_source IS NULL AND end_reason IS NULL)
               OR
               (ended_at IS NOT NULL AND end_source IS NOT NULL AND end_source <> ''
                 AND end_reason IS NOT NULL AND end_reason <> '' AND ended_at >= started_at)
             )
             """
           )
  end
end
