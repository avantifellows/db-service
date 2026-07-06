defmodule Dbservice.Repo.Migrations.ClearDuplicateStudentIdentifiersForLmsIndexes do
  use Ecto.Migration

  def up do
    execute("""
    WITH duplicate_student_ids AS (
      SELECT id
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY student_id ORDER BY id) AS row_number
        FROM student
        WHERE student_id IS NOT NULL AND BTRIM(student_id) <> ''
      ) ranked
      WHERE row_number > 1
    )
    UPDATE student
    SET student_id = NULL
    WHERE id IN (SELECT id FROM duplicate_student_ids);
    """)

    execute("""
    WITH duplicate_apaar_ids AS (
      SELECT id
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY apaar_id ORDER BY id) AS row_number
        FROM student
        WHERE apaar_id IS NOT NULL AND BTRIM(apaar_id) <> ''
      ) ranked
      WHERE row_number > 1
    )
    UPDATE student
    SET apaar_id = NULL
    WHERE id IN (SELECT id FROM duplicate_apaar_ids);
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT student_id
        FROM student
        WHERE student_id IS NOT NULL AND BTRIM(student_id) <> ''
        GROUP BY student_id
        HAVING COUNT(*) > 1
      ) THEN
        RAISE EXCEPTION 'student.student_id still has duplicate non-null values';
      END IF;

      IF EXISTS (
        SELECT apaar_id
        FROM student
        WHERE apaar_id IS NOT NULL AND BTRIM(apaar_id) <> ''
        GROUP BY apaar_id
        HAVING COUNT(*) > 1
      ) THEN
        RAISE EXCEPTION 'student.apaar_id still has duplicate non-null values';
      END IF;
    END $$;
    """)
  end

  def down do
    :ok
  end
end
