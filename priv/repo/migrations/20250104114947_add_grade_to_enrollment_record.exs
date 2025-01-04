defmodule Dbservice.Repo.Migrations.AddGradeToEnrollmentRecord do
  use Ecto.Migration

  def change do
    # First create entries in group table for grades
    execute """
    INSERT INTO "group" (type, child_id, inserted_at, updated_at)
    SELECT DISTINCT
        'grade' as type,
        g.id as child_id,
        NOW(),
        NOW()
    FROM grade g
    WHERE NOT EXISTS (
        SELECT 1 FROM "group"
        WHERE type = 'grade' AND child_id = g.id
    );
    """

    # Create grade enrollment records
    execute("""
    -- Create enrollment records for grades
    WITH grade_enrollments AS (
        SELECT DISTINCT
            er.user_id,
            g.id AS group_id,
            'grade' AS group_type,
            er.academic_year,
            er.start_date,
            true AS is_current
        FROM enrollment_record er
        JOIN grade g ON g.id = er.grade_id
        WHERE er.grade_id IS NOT NULL
          AND er.academic_year IS NOT NULL
          AND er.start_date IS NOT NULL
    )
    INSERT INTO enrollment_record (
        user_id,
        group_id,
        group_type,
        academic_year,
        start_date,
        is_current,
        inserted_at,
        updated_at
    )
    SELECT
        user_id,
        group_id,
        group_type,
        academic_year,
        start_date,
        is_current,
        NOW(),
        NOW()
    FROM grade_enrollments;
    """)

    # Create corresponding group_user entries
    execute """
    WITH grade_users AS (
        SELECT DISTINCT
            er.user_id,
            g.id as group_id
        FROM enrollment_record er
        JOIN grade gr ON gr.id = er.grade_id
        JOIN "group" g ON g.type = 'grade' AND g.child_id = gr.id
        WHERE er.grade_id IS NOT NULL
    )
    INSERT INTO group_user (
        user_id,
        group_id,
        inserted_at,
        updated_at
    )
    SELECT
        user_id,
        group_id,
        NOW(),
        NOW()
    FROM grade_users
    ON CONFLICT (user_id, group_id) DO NOTHING;
    """
  end
end
