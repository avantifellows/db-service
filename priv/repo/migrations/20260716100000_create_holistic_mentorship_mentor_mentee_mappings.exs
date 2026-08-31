defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipMentorMenteeMappings do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_mentor_mentee_mappings) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :mentor_user_id, references(:user, on_delete: :nothing), null: false
      add :school_id, references(:school, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :academic_year, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :assigned_by_user_id, references(:user, on_delete: :nothing)
      add :assignment_source, :string, null: false
      add :ended_at, :utc_datetime
      add :ended_by_user_id, references(:user, on_delete: :nothing)
      add :end_source, :string
      add :end_reason, :string

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(
             :holistic_mentorship_mentor_mentee_mappings,
             [:student_id, :academic_year],
             where: "ended_at IS NULL",
             name: :hm_mappings_active_student_year_unique
           )

    create index(
             :holistic_mentorship_mentor_mentee_mappings,
             [:school_id, :academic_year, :student_id],
             where: "ended_at IS NULL",
             name: :hm_mappings_active_school_year_idx
           )

    create index(
             :holistic_mentorship_mentor_mentee_mappings,
             [:mentor_user_id, :academic_year, :student_id],
             where: "ended_at IS NULL",
             name: :hm_mappings_active_mentor_year_idx
           )

    create index(
             :holistic_mentorship_mentor_mentee_mappings,
             [:student_id, :academic_year, :started_at],
             name: :hm_mappings_student_history_idx
           )

    create constraint(
             :holistic_mentorship_mentor_mentee_mappings,
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
