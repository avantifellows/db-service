defmodule Dbservice.Repo.Migrations.CreateAcademicMentorshipMapping do
  use Ecto.Migration

  def change do
    create table(:academic_mentorship_mentor_mentee_mapping) do
      add :mentor_id, references(:user_permission, on_delete: :nothing), null: false
      add :mentee_id, references(:user, on_delete: :nothing), null: false
      add :academic_year, :string, null: false
      add :created_by, :string, null: false
      add :updated_by, :string
      add :deleted_at, :utc_datetime

      timestamps(default: fragment("now()"), null: false)
    end

    create index(:academic_mentorship_mentor_mentee_mapping, [:mentor_id])
    create index(:academic_mentorship_mentor_mentee_mapping, [:academic_year])

    create unique_index(
             :academic_mentorship_mentor_mentee_mapping,
             [:mentee_id, :academic_year],
             where: "deleted_at IS NULL",
             name: :active_mentee_academic_year_unique
           )
  end
end
