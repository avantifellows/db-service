defmodule Dbservice.Repo.Migrations.WidenLmsCurriculumPlanExamTracks do
  use Ecto.Migration

  # A Curriculum Plan may now serve CET as well as JEE Main, JEE Advanced and NEET.
  # Math Foundation stays out. Also indexes the plan tables' foreign keys that no existing
  # index leads with. Mirrored by af_lms's e2e fixture
  # `20261023091700_widen_lms_curriculum_plan_exam_tracks.sql`; keep the two in step.
  def up do
    replace_exam_tracks_constraint("'jee_main', 'jee_advanced', 'neet', 'cet'")

    create index(:lms_curriculum_plans, [:grade_id])
    create index(:lms_curriculum_plan_chapters, [:chapter_id])
    create index(:lms_curriculum_plan_assignments, [:grade_id])
  end

  def down do
    drop index(:lms_curriculum_plan_assignments, [:grade_id])
    drop index(:lms_curriculum_plan_chapters, [:chapter_id])
    drop index(:lms_curriculum_plans, [:grade_id])

    replace_exam_tracks_constraint("'jee_main', 'jee_advanced', 'neet'")
  end

  defp replace_exam_tracks_constraint(tracks) do
    drop constraint(:lms_curriculum_plans, :lms_curriculum_plans_exam_tracks_check)

    create constraint(:lms_curriculum_plans, :lms_curriculum_plans_exam_tracks_check,
             check: """
             cardinality(exam_tracks) > 0
             AND exam_tracks <@ ARRAY[#{tracks}]::text[]
             """
           )
  end
end
