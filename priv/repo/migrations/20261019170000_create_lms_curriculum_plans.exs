defmodule Dbservice.Repo.Migrations.CreateLmsCurriculumPlans do
  use Ecto.Migration

  # LMS-owned Curriculum Plans (af_lms #417 / #420). Admins date each in-syllabus Chapter of
  # a Grade's served Exam Tracks and assign exactly one plan per Centre + Grade + academic
  # year. The LMS app reads and writes these tables directly, so there is no
  # schema/context/controller here. This migration is the production schema (af_lms ADR
  # 0001), mirrored by af_lms's e2e fixture `20261019120000_add_lms_curriculum_plans.sql`;
  # keep the two in step. af_lms relies on the plan-chapter unique key for
  # ON CONFLICT (plan_id, chapter_id) and maps a unique violation on the assignment key to
  # 409. It does not use constraint names; they match the fixture only for parity.
  #
  # "Closed" is derived from closure_date and never stored, so status is draft | active.
  def change do
    create table(:lms_curriculum_plans) do
      add :title, :text, null: false
      add :academic_year, :text, null: false
      add :grade_id, references(:grade, on_delete: :nothing), null: false
      add :exam_tracks, {:array, :text}, null: false
      add :status, :text, null: false, default: "draft"
      add :closure_date, :date, null: false
      add :activated_at, :naive_datetime_usec
      add :inserted_by_email, :text
      add :updated_by_email, :text

      timestamps(
        type: :naive_datetime_usec,
        default: fragment("(now() AT TIME ZONE 'UTC')"),
        null: false
      )
    end

    create constraint(:lms_curriculum_plans, :lms_curriculum_plans_title_check,
             check: "btrim(title) <> ''"
           )

    create constraint(:lms_curriculum_plans, :lms_curriculum_plans_academic_year_check,
             check: ~S"""
             academic_year ~ '^\d{4}-\d{4}$'
             AND split_part(academic_year, '-', 2)::integer = split_part(academic_year, '-', 1)::integer + 1
             """
           )

    create constraint(:lms_curriculum_plans, :lms_curriculum_plans_exam_tracks_check,
             check: """
             cardinality(exam_tracks) > 0
             AND exam_tracks <@ ARRAY['jee_main', 'jee_advanced', 'neet']::text[]
             """
           )

    create constraint(:lms_curriculum_plans, :lms_curriculum_plans_status_check,
             check: "status IN ('draft', 'active')"
           )

    create index(:lms_curriculum_plans, [:academic_year, :grade_id],
             name: :lms_curriculum_plans_academic_year_grade_index
           )

    create table(:lms_curriculum_plan_chapters) do
      add :plan_id, references(:lms_curriculum_plans, on_delete: :delete_all), null: false
      add :chapter_id, references(:chapter, on_delete: :nothing), null: false
      add :due_date, :date
      add :test_date, :date
      add :inserted_by_email, :text
      add :updated_by_email, :text

      timestamps(
        type: :naive_datetime_usec,
        default: fragment("(now() AT TIME ZONE 'UTC')"),
        null: false
      )
    end

    create constraint(
             :lms_curriculum_plan_chapters,
             :lms_curriculum_plan_chapters_test_date_requires_due_date,
             check: "test_date IS NULL OR due_date IS NOT NULL"
           )

    # A UNIQUE constraint (not just a unique index) to match the af_lms fixture exactly;
    # af_lms upserts plan chapters with ON CONFLICT (plan_id, chapter_id).
    execute(
      """
      ALTER TABLE lms_curriculum_plan_chapters
        ADD CONSTRAINT lms_curriculum_plan_chapters_plan_id_chapter_id_index
        UNIQUE (plan_id, chapter_id)
      """,
      """
      ALTER TABLE lms_curriculum_plan_chapters
        DROP CONSTRAINT lms_curriculum_plan_chapters_plan_id_chapter_id_index
      """
    )

    create table(:lms_curriculum_plan_assignments) do
      add :plan_id, references(:lms_curriculum_plans, on_delete: :delete_all), null: false
      add :centre_id, references(:centres, on_delete: :nothing), null: false
      # Copied from the plan so the unique key enforces one plan per Centre + Grade + year;
      # af_lms checks they match the plan inside the write transaction.
      add :grade_id, references(:grade, on_delete: :nothing), null: false
      add :academic_year, :text, null: false
      add :inserted_by_email, :text
      add :updated_by_email, :text

      timestamps(
        type: :naive_datetime_usec,
        default: fragment("(now() AT TIME ZONE 'UTC')"),
        null: false
      )
    end

    # af_lms maps a unique violation here (23505) to 409 on concurrent assignment saves.
    execute(
      """
      ALTER TABLE lms_curriculum_plan_assignments
        ADD CONSTRAINT lms_curriculum_plan_assignments_centre_grade_year_index
        UNIQUE (centre_id, grade_id, academic_year)
      """,
      """
      ALTER TABLE lms_curriculum_plan_assignments
        DROP CONSTRAINT lms_curriculum_plan_assignments_centre_grade_year_index
      """
    )

    create index(:lms_curriculum_plan_assignments, [:plan_id],
             name: :lms_curriculum_plan_assignments_plan_id_index
           )
  end
end
