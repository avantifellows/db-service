defmodule Dbservice.Repo.Migrations.CreateCmsStatusTable do
  use Ecto.Migration

  def up do
    # Create cms_status table
    create table(:cms_status) do
      add :name, :string, null: false

      timestamps()
    end

    # Add unique index on name
    create unique_index(:cms_status, [:name])

    # Extract unique statuses from resource table and insert into cms_status
    # Convert to lowercase for consistency
    execute """
    INSERT INTO cms_status (name, inserted_at, updated_at)
    SELECT DISTINCT
      LOWER(cms_status),
      NOW(),
      NOW()
    FROM resource
    WHERE cms_status IS NOT NULL
    ORDER BY LOWER(cms_status)
    """

    # Add foreign key column to resource table
    alter table(:resource) do
      add :cms_status_id, references(:cms_status, on_delete: :restrict)
    end

    # Update resource table to link with cms_status
    execute """
    UPDATE resource r
    SET cms_status_id = cs.id
    FROM cms_status cs
    WHERE LOWER(r.cms_status) = cs.name
    """

    # Create index on the foreign key
    create index(:resource, [:cms_status_id])

    # Drop the old cms_status column
    alter table(:resource) do
      remove :cms_status
    end
  end

  def down do
    # Restore cms_status column data if it was removed
    alter table(:resource) do
      add :cms_status, :string
    end

    # Restore data back to the string column
    execute """
    UPDATE resource r
    SET cms_status = cs.name
    FROM cms_status cs
    WHERE r.cms_status_id = cs.id
    """

    # Drop the foreign key and index
    drop index(:resource, [:cms_status_id])

    alter table(:resource) do
      remove :cms_status_id
    end

    # Drop cms_status table
    drop table(:cms_status)
  end
end
