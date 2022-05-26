defmodule Dbservice.Repo.Migrations.CreateTeacher do
  use Ecto.Migration

  def change do
    create table(:teacher) do
      add :designation, :string
      add :subject, :string
      add :grade, :string
      add :user_id, references(:user, on_delete: :nothing)
      add :school_id, references(:school, on_delete: :nothing)
      add :program_manager_id, references(:user, on_delete: :nothing)

      timestamps()
    end

    create index(:teacher, [:user_id])
    create index(:teacher, [:school_id])
    create index(:teacher, [:program_manager_id])
  end
end
