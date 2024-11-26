defmodule Dbservice.Repo.Migrations.CreateChapterCurriculumTable do
  use Ecto.Migration

  def change do
    create table(:chapter_curriculum) do
      add :chapter_id, references(:chapter, on_delete: :nothing)
      add :curriculum_id, references(:curriculum, on_delete: :nothing)
      add :priority, :string
      add :weightage, :integer

      timestamps()
    end
  end
end
