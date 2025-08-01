defmodule Dbservice.Repo.Migrations.ModifyChapterTable do
  use Ecto.Migration

  def up do
    # First create a temporary column
    alter table(:chapter) do
      add :name_jsonb, :jsonb
    end

    # Execute raw SQL to convert existing name data to JSONB array with clean strings
    execute """
    UPDATE chapter
    SET name_jsonb = (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'lang_code', (SELECT code FROM language WHERE name = 'English'),
          'chapter', trim(regexp_replace(name, E'\\r|\\n', '', 'g'))
        )
      )
    )
    """

    # Drop the old name column and rename name_jsonb to name
    alter table(:chapter) do
      remove :name
    end

    rename table(:chapter), :name_jsonb, to: :name
  end

  def down do
    # First create a temporary string column
    alter table(:chapter) do
      add :name_string, :string
    end

    # Convert JSONB back to string (taking English or first entry)
    execute """
    UPDATE chapter
    SET name_string = (
      COALESCE(
        (SELECT chapter
         FROM jsonb_array_elements(name) AS elements
         WHERE elements->>'lang_code' = (SELECT code FROM language WHERE name = 'English')
         LIMIT 1),
        (SELECT chapter
         FROM jsonb_array_elements(name) AS elements
         LIMIT 1)
      )
    )
    """

    # Drop the JSONB column and rename string column back to name
    alter table(:chapter) do
      remove :name
    end

    rename table(:chapter), :name_string, to: :name
  end
end
