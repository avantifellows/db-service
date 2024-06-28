defmodule Dbservice.Repo.Migrations.UpdateStudentStatus do
  use Ecto.Migration

  def change do
    rename table(:enrollment_record), :group_id, to: :group_type_id

    execute("""
    UPDATE student
    SET status = CASE
                   WHEN EXISTS (
                     SELECT 1
                     FROM enrollment_record
                     WHERE enrollment_record.user_id = student.user_id
                     AND enrollment_record.group_type = 'batch'
                   ) THEN 'enrolled'
                   ELSE 'registered'
                 END
    WHERE status IS NULL
    AND user_id IN (
      SELECT user_id
      FROM enrollment_record
      WHERE academic_year = '2024-2025'
    )
    """)

    # Insert enrollment record for the updated students
    execute("""
    INSERT INTO enrollment_record (user_id, group_type, group_type_id, academic_year, is_current, grade_id, start_date, inserted_at, updated_at)
    SELECT
    er.user_id,
    'status' AS group_type,
    (SELECT id FROM status WHERE title = s.status) AS group_type_id,
    er.academic_year,
    TRUE AS is_current,
    er.grade_id,
    er.start_date,
    NOW() AS inserted_at,
    NOW() AS updated_at
    FROM
    enrollment_record er
    JOIN
    student s ON s.user_id = er.user_id
    WHERE
    s.status IN ('enrolled', 'registered')
    AND er.group_type = 'batch'
    AND er.academic_year = '2024-2025';

    """)
  end
end
