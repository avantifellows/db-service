defmodule Dbservice.Repo.Migrations.UpdateSchoolEnrollmentFor2025 do
  use Ecto.Migration

  def up do
    execute("""
    -- Step 1: Mark current 2024-2025 school records as not current
    UPDATE enrollment_record
    SET is_current = false,
        end_date = CURRENT_DATE
    WHERE user_id IN (
        SELECT user_id FROM student
    )
    AND academic_year = '2024-2025'
    AND group_type = 'school'
    AND is_current = true
    AND (end_date IS NULL OR end_date = CURRENT_DATE);
    """)

    execute("""
    -- Step 2: Insert new 2025-2026 school records
    INSERT INTO enrollment_record (
        user_id,
        start_date,
        academic_year,
        group_id,
        group_type,
        is_current,
        inserted_at,
        updated_at
    )
    SELECT
        user_id,
        CURRENT_DATE,
        '2025-2026',
        group_id,
        group_type,
        true,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    FROM enrollment_record
    WHERE academic_year = '2024-2025'
    AND group_type = 'school'
    AND (end_date = CURRENT_DATE OR end_date IS NULL);
    """)
  end

  def down do
    execute("""
    DELETE FROM enrollment_record
    WHERE academic_year = '2025-2026'
    AND group_type = 'school'
    AND start_date = CURRENT_DATE;
    """)

    execute("""
    UPDATE enrollment_record
    SET is_current = true,
        end_date = NULL
    WHERE academic_year = '2024-2025'
    AND group_type = 'school'
    AND end_date = CURRENT_DATE;
    """)
  end
end
