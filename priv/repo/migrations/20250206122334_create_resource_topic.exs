defmodule Dbservice.Repo.Migrations.CreateResourceTopic do
  use Ecto.Migration

  def change do
    # Create the new table
    create table(:resource_topic) do
      add :resource_id, references(:resource, on_delete: :nothing)
      add :topic_id, references(:topic, on_delete: :nothing)

      timestamps()
    end

    # Migrate existing data, excluding NULL topic_id values
    execute """
    INSERT INTO resource_topic (resource_id, topic_id, inserted_at, updated_at)
    SELECT id, topic_id, NOW(), NOW() FROM resource
    WHERE topic_id IS NOT NULL
    """

    alter table(:resource) do
      remove :topic_id
    end
  end
end
