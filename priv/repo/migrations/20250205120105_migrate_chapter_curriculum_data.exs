defmodule Dbservice.Repo.Migrations.MigrateChapterCurriculumData do
  use Ecto.Migration

  def up do
    # First, let's create a function to execute raw SQL
    execute """
    INSERT INTO chapter_curriculum (chapter_id, curriculum_id, inserted_at, updated_at)
    SELECT id, curriculum_id, inserted_at, updated_at
    FROM chapter
    WHERE curriculum_id IS NOT NULL;
    """

    alter table(:chapter) do
      remove :curriculum_id
    end
  end

  def down do
    alter table(:chapter) do
      add :curriculum_id, references(:curriculum, on_delete: :nothing)
    end

    # In case we need to rollback, we'll clear the chapter_curriculum table
    execute """
    DELETE FROM chapter_curriculum;
    """
  end
end
