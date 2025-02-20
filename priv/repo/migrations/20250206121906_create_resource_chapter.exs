defmodule Dbservice.Repo.Migrations.CreateResourceChapter do
  use Ecto.Migration

  def change do
    # Create the new table
    create table(:resource_chapter) do
      add :resource_id, references(:resource, on_delete: :nothing)
      add :chapter_id, references(:chapter, on_delete: :nothing)

      timestamps()
    end

    # Migrate existing data, excluding NULL chapter_id values
    execute """
    INSERT INTO resource_chapter (resource_id, chapter_id, inserted_at, updated_at)
    SELECT id, chapter_id, NOW(), NOW() FROM resource
    WHERE chapter_id IS NOT NULL
    """

    alter table(:resource) do
      remove :chapter_id
    end
  end
end
