defmodule Dbservice.Repo.Migrations.CreateAcademicMentorshipMentorMenteeMappings do
  use Ecto.Migration

  def change do
    create table(:academic_mentorship_mentor_mentee_mappings) do
      add :school_id, references(:school, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing)
      add :academic_year, :string, null: false
      add :mentor_user_id, references(:user, on_delete: :nothing), null: false
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :assigned_at, :utc_datetime, null: false
      add :assigned_by_user_id, references(:user, on_delete: :nothing), null: false
      add :ended_at, :utc_datetime
      add :ended_by_user_id, references(:user, on_delete: :nothing)
      add :end_reason, :text

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(
             :academic_mentorship_mentor_mentee_mappings,
             [:school_id, :academic_year, :student_id],
             where: "ended_at IS NULL",
             name: :am_mentor_mentee_active_mentee_unique
           )

    create index(
             :academic_mentorship_mentor_mentee_mappings,
             [:school_id, :academic_year],
             where: "ended_at IS NULL",
             name: :am_mentor_mentee_school_year_active_idx
           )

    create index(
             :academic_mentorship_mentor_mentee_mappings,
             [:mentor_user_id, :academic_year],
             where: "ended_at IS NULL",
             name: :am_mentor_mentee_mentor_year_active_idx
           )

    create index(:academic_mentorship_mentor_mentee_mappings, [:mentor_user_id],
             name: :am_mentor_mentee_teacher_history_idx
           )
  end
end
