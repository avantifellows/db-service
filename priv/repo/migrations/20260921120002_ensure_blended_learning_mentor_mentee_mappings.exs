defmodule Dbservice.Repo.Migrations.EnsureBlendedLearningMentorMenteeMappings do
  use Ecto.Migration

  # Staging recorded version 20260921120000 for scholarship_session_student_links
  # (it shared that version with create_blended_learning_mentor_mentee_mappings),
  # so Ecto treats the Blended Learning migration as already run there and never
  # creates its table. This re-applies that migration idempotently. It is a no-op
  # wherever 20260921120000 really created the table (prod, fresh DBs).
  #
  # Keep this in sync with 20260921120000_create_blended_learning_mentor_mentee_mappings.exs.

  @mapping_table "blended_learning_mentor_mentee_mappings"

  def up do
    create_if_not_exists table(@mapping_table) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :mentor_user_id, references(:user, on_delete: :nothing), null: false
      add :school_id, references(:school, on_delete: :nothing)
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :academic_year, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :assigned_by_user_id, references(:user, on_delete: :nothing)
      add :assigned_by_email, :string, size: 255
      add :assignment_source, :string, null: false
      add :assignment_audit_reason, :string, size: 500
      add :ended_at, :utc_datetime
      add :ended_by_user_id, references(:user, on_delete: :nothing)
      add :ended_by_email, :string, size: 255
      add :end_source, :string
      add :end_reason, :string
      add :end_audit_reason, :string, size: 500

      timestamps(default: fragment("now()"), null: false)
    end

    create_if_not_exists unique_index(
                           @mapping_table,
                           [:student_id, :academic_year],
                           where: "ended_at IS NULL",
                           name: :blm_mappings_active_student_year_unique
                         )

    create_if_not_exists index(
                           @mapping_table,
                           [:program_id, :academic_year, :student_id],
                           where: "ended_at IS NULL",
                           name: :blm_mappings_active_program_year_idx
                         )

    create_if_not_exists index(
                           @mapping_table,
                           [:mentor_user_id, :academic_year, :student_id],
                           where: "ended_at IS NULL",
                           name: :blm_mappings_active_mentor_year_idx
                         )

    create_if_not_exists index(
                           @mapping_table,
                           [:student_id, :academic_year, :started_at],
                           name: :blm_mappings_student_history_idx
                         )

    # Postgres has no ADD CONSTRAINT IF NOT EXISTS, and Ecto has no
    # create_if_not_exists for constraints.
    add_check_if_missing(:blm_mappings_lifecycle_check, """
    assignment_source <> '' AND
    (
      ended_at IS NULL AND ended_by_user_id IS NULL AND ended_by_email IS NULL AND
      end_source IS NULL AND end_reason IS NULL AND end_audit_reason IS NULL
      OR
      ended_at IS NOT NULL AND end_source IS NOT NULL AND end_source <> '' AND
      end_reason IS NOT NULL AND end_reason <> '' AND ended_at >= started_at
    )
    """)

    add_check_if_missing(:blm_mappings_audit_fields_check, """
    (assigned_by_email IS NULL OR assigned_by_email ~ '[^[:space:]]') AND
    (assignment_audit_reason IS NULL OR assignment_audit_reason ~ '[^[:space:]]') AND
    (ended_by_email IS NULL OR ended_by_email ~ '[^[:space:]]') AND
    (end_audit_reason IS NULL OR end_audit_reason ~ '[^[:space:]]')
    """)
  end

  # Deliberately a no-op: on prod the table belongs to 20260921120000, and
  # rolling this back must not drop it.
  def down, do: :ok

  defp add_check_if_missing(name, check) do
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = '#{name}'
          AND conrelid = '#{@mapping_table}'::regclass
      ) THEN
        ALTER TABLE #{@mapping_table} ADD CONSTRAINT #{name} CHECK (#{check});
      END IF;
    END
    $$;
    """)
  end
end
