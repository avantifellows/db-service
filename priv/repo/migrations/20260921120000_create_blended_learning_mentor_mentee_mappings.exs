defmodule Dbservice.Repo.Migrations.CreateBlendedLearningMentorMenteeMappings do
  use Ecto.Migration

  @mapping_table "blended_learning_mentor_mentee_mappings"

  def change do
    create table(@mapping_table) do
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

    create unique_index(
             @mapping_table,
             [:student_id, :academic_year],
             where: "ended_at IS NULL",
             name: :blm_mappings_active_student_year_unique
           )

    create index(
             @mapping_table,
             [:program_id, :academic_year, :student_id],
             where: "ended_at IS NULL",
             name: :blm_mappings_active_program_year_idx
           )

    create index(
             @mapping_table,
             [:mentor_user_id, :academic_year, :student_id],
             where: "ended_at IS NULL",
             name: :blm_mappings_active_mentor_year_idx
           )

    create index(
             @mapping_table,
             [:student_id, :academic_year, :started_at],
             name: :blm_mappings_student_history_idx
           )

    create constraint(
             @mapping_table,
             :blm_mappings_lifecycle_check,
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
             :blm_mappings_audit_fields_check,
             check: """
             (assigned_by_email IS NULL OR assigned_by_email ~ '[^[:space:]]') AND
             (assignment_audit_reason IS NULL OR assignment_audit_reason ~ '[^[:space:]]') AND
             (ended_by_email IS NULL OR ended_by_email ~ '[^[:space:]]') AND
             (end_audit_reason IS NULL OR end_audit_reason ~ '[^[:space:]]')
             """
           )
  end
end
