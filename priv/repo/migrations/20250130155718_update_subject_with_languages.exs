defmodule Dbservice.Repo.Migrations.UpdateSubjectWithLanguages do
  use Ecto.Migration

  def up do
    # First add temporary columns
    alter table(:subject) do
      add :name_jsonb, :jsonb
    end

    # First update existing subjects
    execute """
    UPDATE subject SET name_jsonb = json_build_array(
      json_build_object('lang_id', 1, 'subject', name),
      json_build_object('lang_id', 2, 'subject',
        CASE
          WHEN name = 'maths' THEN 'गणित'
          WHEN name = 'chemistry' THEN 'रसायन विज्ञान'
          WHEN name = 'biology' THEN 'जीव विज्ञान'
          WHEN name = 'physics' THEN 'भौतिक विज्ञान'
        END),
      json_build_object('lang_id', 3, 'subject',
        CASE
          WHEN name = 'maths' THEN 'கணிதம்'
          WHEN name = 'chemistry' THEN 'வேதியியல்'
          WHEN name = 'biology' THEN 'உயிரியல்'
          WHEN name = 'physics' THEN 'இயற்பியல்'
        END),
      json_build_object('lang_id', 4, 'subject',
        CASE
          WHEN name = 'maths' THEN 'ગણિત'
          WHEN name = 'chemistry' THEN 'રસાયણ વિજ્ઞાન'
          WHEN name = 'biology' THEN 'જીવવિજ્ઞાન'
          WHEN name = 'physics' THEN 'ભૌતિક વિજ્ઞાન'
        END)
    );
    """

    # Drop the old name column and rename the new one
    alter table(:subject) do
      remove :name
    end

    rename table(:subject), :name_jsonb, to: :name

    # Then insert new subjects after the rename
    execute """
    WITH biology_id AS (
      SELECT id FROM subject WHERE name->0->>'subject' = 'biology' LIMIT 1
    )
    INSERT INTO subject (parent_id, name, inserted_at, updated_at)
    VALUES
      ((SELECT id FROM biology_id),
       '[
          {"lang_id": 1, "subject": "botany"},
          {"lang_id": 2, "subject": "वनस्पति विज्ञान"},
          {"lang_id": 3, "subject": "தாவரவியல்"},
          {"lang_id": 4, "subject": "વનસ્પતિશાસ્ત્ર"}
        ]',
        NOW(),
        NOW()
      ),
      ((SELECT id FROM biology_id),
       '[
          {"lang_id": 1, "subject": "zoology"},
          {"lang_id": 2, "subject": "प्राणि विज्ञान"},
          {"lang_id": 3, "subject": "விலங்கியல்"},
          {"lang_id": 4, "subject": "પ્રાણીશાસ્ત્ર"}
        ]',
        NOW(),
        NOW()
      );
    """
  end

  def down do
    alter table(:subject) do
      add :name_string, :string
    end

    execute """
    DELETE FROM subject
    WHERE name->0->>'subject' IN ('botany', 'zoology');

    UPDATE subject
    SET name_string = (name->0->>'subject')::text
    """

    alter table(:subject) do
      remove :name
    end

    rename table(:subject), :name_string, to: :name
  end
end
