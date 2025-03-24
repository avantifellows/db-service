defmodule Dbservice.Repo.Migrations.CreateChapterCurriculumTable do
  use Ecto.Migration

  def up do
    create table(:chapter_curriculum) do
      add :chapter_id, references(:chapter, on_delete: :nothing)
      add :curriculum_id, references(:curriculum, on_delete: :nothing)
      add :priority, :integer
      add :priority_text, :string
      add :weightage, :integer

      timestamps()
    end
  end

  def down do
    drop table(:chapter_curriculum)
  end
end
