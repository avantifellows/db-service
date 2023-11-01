defmodule Dbservice.Repo.Migrations.CreateTeacherProfile do
  use Ecto.Migration

  def change do
    create table(:teacher_profile) do
      add :uuid, :string
      add :designation, :string
      add :subject, :string
      add :school, :string
      add :program_manager, :string
      add :avg_rating, :decimal
      add :user_profile_id, references(:user_profile, on_delete: :nothing)
      add :teacher_id, references(:teacher, on_delete: :nothing)

      timestamps()
    end

    create index(:teacher_profile, [:user_profile_id],
             name: "index_teacher_profile_on_user_profile_id"
           )

    create index(:teacher_profile, [:teacher_id], name: "index_teacher_profile_on_teacher_id")
  end
end
