defmodule Dbservice.Repo.Migrations.CreateTeacherProfile do
  use Ecto.Migration

  def change do
    create table(:teacher_profile) do
      add :teacher_id, :string
      add :school, :string
      add :program_manager, :string
      add :avg_rating, :decimal
      add :user_profile_id, references(:user_profile, on_delete: :nothing)
      add :teacher_fk, references(:teacher, on_delete: :nothing)

      timestamps()
    end

    create index(:teacher_profile, [:user_profile_id],
             name: "index_teacher_profile_on_user_profile_id"
           )

    create index(:teacher_profile, [:teacher_fk], name: "index_teacher_profile_on_teacher_fk")
  end
end
