defmodule Dbservice.Repo.Migrations.ModifyResourceTable do
  use Ecto.Migration

  def up do
    # 1. Convert name to jsonb
    alter table(:resource) do
      add :name_jsonb, :jsonb
    end

    execute """
    UPDATE resource
    SET name_jsonb = (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'lang_code', (SELECT code FROM language WHERE name = 'English'),
          'resource', trim(regexp_replace(name, E'\\r|\\n', '', 'g'))
        )
      )
    )
    """

    alter table(:resource) do
      remove :name
    end

    rename table(:resource), :name_jsonb, to: :name

    # 2. Add subtype column
    alter table(:resource) do
      add :subtype, :string
    end

    # 3. Handle source data migration
    alter table(:resource) do
      add :source, :string
    end

    # Migrate source data and update type_params
    execute """
    UPDATE resource r
    SET
      source = CASE (SELECT name FROM source WHERE id = r.source_id)
        WHEN 'youtube' THEN 'youtube'
        WHEN 'gdrive' THEN 'gdrive'
        WHEN 'PDF ' THEN 'gdrive'
      END,
      type = CASE (SELECT name FROM source WHERE id = r.source_id)
        WHEN 'youtube' THEN 'video'
        WHEN 'gdrive' THEN 'video'
        WHEN 'PDF ' THEN 'document'
      END,
      type_params = CASE
        WHEN type_params IS NULL THEN
          jsonb_build_object(
            'src_link', (SELECT link FROM source WHERE id = r.source_id),
            'resource_type', r.type
          )
        ELSE
          type_params ||
          jsonb_build_object(
            'src_link', (SELECT link FROM source WHERE id = r.source_id),
            'resource_type', r.type
          )
      END
    WHERE source_id IS NOT NULL
    """

    # Remove source_id after migration
    alter table(:resource) do
      remove :source_id
    end

    # 4. Add code column and populate it
    alter table(:resource) do
      add :code, :string
    end

    # Update code based on first letter of type and ID
    execute """
    UPDATE resource
    SET code = UPPER(LEFT(type, 1)) || id::text
    WHERE type IS NOT NULL
    """

    # 5. Change purpose_id to purpose_ids array
    alter table(:resource) do
      add :purpose_ids, {:array, :bigint}
    end

    # Migrate existing purpose_id data to purpose_ids array
    execute """
    UPDATE resource
    SET purpose_ids = ARRAY[purpose_id]
    WHERE purpose_id IS NOT NULL
    """

    alter table(:resource) do
      remove :purpose_id
    end

    # 7. Add skill_ids column
    alter table(:resource) do
      add :skill_ids, {:array, :bigint}
    end

    # 8. Change learning_objective_id to learning_objective_ids array
    alter table(:resource) do
      add :learning_objective_ids, {:array, :integer}
    end

    # Migrate existing learning_objective_id data to learning_objective_ids array
    execute """
    UPDATE resource
    SET learning_objective_ids = ARRAY[learning_objective_id]
    WHERE learning_objective_id IS NOT NULL
    """

    alter table(:resource) do
      remove :learning_objective_id
    end

    # Drop source table after migration
    drop table(:source)
  end

  def down do
    # 1. Revert name back to string
    alter table(:resource) do
      add :name_string, :string
    end

    execute """
    UPDATE resource
    SET name_string = (
      COALESCE(
        (SELECT name
         FROM jsonb_array_elements(name) AS elements
         WHERE (elements->>'lang_id')::integer = (SELECT id FROM language WHERE name = 'English')
         LIMIT 1),
        (SELECT resource
         FROM jsonb_array_elements(name) AS elements
         LIMIT 1)
      )
    )
    """

    alter table(:resource) do
      remove :name
    end

    rename table(:resource), :name_string, to: :name

    # Recreate source table
    create table(:source) do
      add :name, :string
      add :link, :string

      timestamps()
    end

    # Add back source_id
    alter table(:resource) do
      add :source_id, references(:source)
    end

    # Remove new columns
    alter table(:resource) do
      remove :subtype
      remove :source
      remove :type
      remove :code
      remove :purpose_ids
      remove :tag_ids
      remove :skill_ids
      remove :learning_objective_ids
    end

    # Add back original columns
    alter table(:resource) do
      add :purpose_id, references(:purpose)
      add :tag_id, references(:tag)
      add :learning_objective_id, references(:learning_objective)
    end
  end
end
