defmodule Dbservice.Repo.Migrations.AddGradeToEnrollmentRecord do
  use Ecto.Migration

  def change do
    # First create entries in group table for grades
    execute """
    INSERT INTO "group" (type, child_id, inserted_at, updated_at)
    SELECT DISTINCT 'grade' as type, g.id as child_id, NOW(), NOW()
    FROM grade g
    WHERE NOT EXISTS (
      SELECT 1 FROM "group" WHERE type = 'grade' AND child_id = g.id
    );
    """

    # Create corresponding group_user entries - modified to only include latest grade
    execute """
    WITH latest_grade_enrollments AS (
      SELECT DISTINCT ON (er.user_id)
        er.user_id,
        gr.id as grade_id,
        er.inserted_at
      FROM enrollment_record er
      JOIN grade gr ON gr.id = er.grade_id
      WHERE er.grade_id IS NOT NULL
      ORDER BY er.user_id, er.inserted_at DESC
    ),
    grade_users AS (
      SELECT
        lge.user_id,
        g.id as group_id
      FROM latest_grade_enrollments lge
      JOIN "group" g ON g.type = 'grade' AND g.child_id = lge.grade_id
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
    WHERE NOT EXISTS (
      SELECT 1 FROM group_user gu
      WHERE gu.user_id = grade_users.user_id
      AND gu.group_id = grade_users.group_id
    )
    """

    # Create grade enrollment records
    execute("""
    WITH ranked_enrollments AS (
      SELECT
        er.user_id,
        g.id AS group_id,
        'grade' AS group_type,
        er.academic_year,
        er.start_date,
        er.inserted_at,
        ROW_NUMBER() OVER (PARTITION BY er.user_id, g.id ORDER BY er.inserted_at ASC) AS start_rank,
        -- Get latest non-status record for end_date and is_current
        FIRST_VALUE(er.end_date) OVER (
          PARTITION BY er.user_id, g.id
          ORDER BY
            CASE WHEN er.group_type != 'status' THEN 0 ELSE 1 END,
            er.inserted_at DESC
        ) AS latest_end_date,
        FIRST_VALUE(er.is_current) OVER (
          PARTITION BY er.user_id, g.id
          ORDER BY
            CASE WHEN er.group_type != 'status' THEN 0 ELSE 1 END,
            er.inserted_at DESC
        ) AS latest_is_current
      FROM enrollment_record er
      JOIN grade g ON g.id = er.grade_id
      WHERE er.grade_id IS NOT NULL
    ),
    grade_enrollments AS (
      SELECT
        user_id,
        group_id,
        group_type,
        academic_year,
        MIN(start_date) FILTER (WHERE start_rank = 1) AS start_date,
        MAX(latest_end_date) AS end_date,
        bool_or(latest_is_current) AS is_current
      FROM ranked_enrollments
      GROUP BY user_id, group_id, group_type, academic_year
    )
    INSERT INTO enrollment_record (
      user_id,
      group_id,
      group_type,
      academic_year,
      start_date,
      end_date,
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
      end_date,
      is_current,
      NOW(),
      NOW()
    FROM grade_enrollments;
    """)
  end
end
