defmodule Dbservice.Repo.Migrations.ModifyTopicTable do
  use Ecto.Migration

  def change do
    # First create a temporary jsonb column
    alter table(:topic) do
      add :name_jsonb, :jsonb
      remove :grade_id
      remove :tag_id
    end

    # Execute raw SQL to convert existing name data to JSONB array with clean strings
    execute """
    UPDATE topic
    SET name_jsonb = (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'lang_code', (SELECT code FROM language WHERE name = 'English'),
          'topic', trim(regexp_replace(name, E'\\r|\\n', '', 'g'))
        )
      )
    )
    """

    # Drop the old name column and rename name_jsonb to name
    alter table(:topic) do
      remove :name
    end

    rename table(:topic), :name_jsonb, to: :name
  end

  def down do
    # First create a temporary string column
    alter table(:topic) do
      add :name_string, :string
      add :grade_id, references(:grade, on_delete: :nothing)
      add :tag_id, references(:tag, on_delete: :nothing)
    end

    # Convert JSONB back to string (taking English or first entry)
    execute """
    UPDATE topic
    SET name_string = (
      COALESCE(
        (SELECT topic
         FROM jsonb_array_elements(name) AS elements
         WHERE (elements->>'lang_id')::integer = (SELECT id FROM language WHERE name = 'English')
         LIMIT 1),
        (SELECT topic
         FROM jsonb_array_elements(name) AS elements
         LIMIT 1)
      )
    )
    """

    # Drop the JSONB column and rename string column back to name
    alter table(:topic) do
      remove :name
    end

    rename table(:topic), :name_string, to: :name
  end
end
