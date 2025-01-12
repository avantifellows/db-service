defmodule Dbservice.Repo.Migrations.CreateProblemCurriculumTable do
  use Ecto.Migration

  def up do
    create table(:problem_curriculum) do
      add :problem_id, references(:resource)
      add :curriculum_id, references(:curriculum)
      add :difficulty_level, :string

      timestamps()
    end
  end

  def down do
    drop table(:problem_curriculum)
  end
end
