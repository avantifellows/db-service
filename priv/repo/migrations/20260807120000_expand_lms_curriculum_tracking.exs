defmodule Dbservice.Repo.Migrations.ExpandLmsCurriculumTracking do
  use Ecto.Migration

  @exam_tracks "('jee_main', 'jee_advanced', 'neet', 'cet', 'math_foundation')"

  def up do
    alter table(:lms_curriculum_logs) do
      add :log_type, :string, size: 32, null: false, default: "regular"
      add :chapter_id, references(:chapter, on_delete: :nothing)
      modify :duration_minutes, :integer, null: true
    end

    replace_exam_track_constraint(:lms_chapter_exam_configs)
    replace_exam_track_constraint(:lms_curriculum_logs)
    replace_exam_track_constraint(:lms_curriculum_chapter_completions)

    drop constraint(:lms_curriculum_logs, :lms_curriculum_logs_duration_minutes_check)

    create constraint(:lms_curriculum_logs, :lms_curriculum_logs_duration_minutes_check,
             check: """
             CASE log_type
               WHEN 'class_cancelled' THEN duration_minutes IS NULL
               ELSE duration_minutes IS NOT NULL
                 AND duration_minutes > 0
                 AND duration_minutes <= 720
             END
             """
           )

    create constraint(:lms_curriculum_logs, :lms_curriculum_logs_log_type_check,
             check: "log_type IN ('regular', 'class_cancelled', 'doubt_solving')"
           )

    create constraint(:lms_curriculum_logs, :lms_curriculum_logs_chapter_id_check,
             check: """
             CASE log_type
               WHEN 'regular' THEN chapter_id IS NULL
               ELSE chapter_id IS NOT NULL
             END
             """
           )

    create unique_index(
             :lms_curriculum_logs,
             [
               :school_code,
               :program_id,
               :grade_id,
               :subject_id,
               :exam_track,
               :chapter_id,
               :log_date
             ],
             where: "log_type = 'class_cancelled' AND deleted_at IS NULL",
             name: :lms_curriculum_logs_active_class_cancelled_unique
           )
  end

  def down do
    drop_if_exists index(:lms_curriculum_logs, [],
                     name: :lms_curriculum_logs_active_class_cancelled_unique
                   )

    drop constraint(:lms_curriculum_logs, :lms_curriculum_logs_chapter_id_check)
    drop constraint(:lms_curriculum_logs, :lms_curriculum_logs_log_type_check)
    drop constraint(:lms_curriculum_logs, :lms_curriculum_logs_duration_minutes_check)

    create constraint(:lms_curriculum_logs, :lms_curriculum_logs_duration_minutes_check,
             check: "duration_minutes > 0 AND duration_minutes <= 720"
           )

    restore_exam_track_constraint(:lms_chapter_exam_configs)
    restore_exam_track_constraint(:lms_curriculum_logs)
    restore_exam_track_constraint(:lms_curriculum_chapter_completions)

    alter table(:lms_curriculum_logs) do
      modify :duration_minutes, :integer, null: false
      remove :chapter_id
      remove :log_type
    end
  end

  defp replace_exam_track_constraint(table) do
    name = String.to_atom("#{table}_exam_track_check")
    drop constraint(table, name)
    create constraint(table, name, check: "exam_track IN #{@exam_tracks}")
  end

  defp restore_exam_track_constraint(table) do
    name = String.to_atom("#{table}_exam_track_check")
    drop constraint(table, name)
    create constraint(table, name, check: "exam_track IN ('jee_main', 'jee_advanced', 'neet')")
  end
end
