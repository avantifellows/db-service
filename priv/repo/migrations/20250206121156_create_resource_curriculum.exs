defmodule Dbservice.Repo.Migrations.CreateResourceCurriculum do
  use Ecto.Migration

  def change do
    # Create the new table
    create table(:resource_curriculum) do
      add :resource_id, references(:resource, on_delete: :nothing)
      add :curriculum_id, references(:curriculum, on_delete: :nothing)
      add :difficulty_level, :string

      timestamps()
    end

    # Migrate existing data
    execute """
    INSERT INTO resource_curriculum (resource_id, curriculum_id, inserted_at, updated_at)
    SELECT id, curriculum_id, NOW(), NOW() FROM resource
    WHERE curriculum_id IS NOT NULL
    """

    alter table(:resource) do
      remove :curriculum_id
      remove :difficulty_level
    end
  end
end
