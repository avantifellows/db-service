defmodule Dbservice.Repo.Migrations.CreateLmsCurriculumTrackingTables do
  use Ecto.Migration

  def change do
    create table(:lms_chapter_exam_configs) do
      add :chapter_id, references(:chapter, on_delete: :nothing), null: false
      add :exam_track, :string, size: 32, null: false
      add :is_in_syllabus, :boolean, default: true, null: false
      add :prescribed_minutes, :integer, default: 0, null: false
      add :coverage_sequence, :integer, null: false
      add :inserted_by_email, :string, size: 255
      add :updated_by_email, :string, size: 255

      timestamps(default: fragment("now()"), null: false)
    end

    create constraint(:lms_chapter_exam_configs, :lms_chapter_exam_configs_exam_track_check,
             check: "exam_track IN ('jee_main', 'jee_advanced', 'neet')"
           )

    create constraint(
             :lms_chapter_exam_configs,
             :lms_chapter_exam_configs_prescribed_minutes_check,
             check: "prescribed_minutes >= 0"
           )

    create constraint(
             :lms_chapter_exam_configs,
             :lms_chapter_exam_configs_coverage_sequence_check,
             check: "coverage_sequence > 0"
           )

    create constraint(
             :lms_chapter_exam_configs,
             :lms_chapter_exam_configs_out_of_syllabus_minutes_check,
             check: "is_in_syllabus OR prescribed_minutes = 0"
           )

    create unique_index(:lms_chapter_exam_configs, [:chapter_id, :exam_track],
             name: :lms_chapter_exam_configs_chapter_track_unique
           )

    create index(:lms_chapter_exam_configs, [:exam_track, :chapter_id],
             name: :lms_chapter_exam_configs_exam_track_chapter_id_index
           )

    create table(:lms_curriculum_logs) do
      add :school_code, :string, size: 255, null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :grade_id, references(:grade, on_delete: :nothing), null: false
      add :subject_id, references(:subject, on_delete: :nothing), null: false
      add :exam_track, :string, size: 32, null: false
      add :log_date, :date, null: false
      add :duration_minutes, :integer, null: false
      add :created_by_email, :string, size: 255
      add :inserted_by_email, :string, size: 255
      add :updated_by_email, :string, size: 255
      add :deleted_at, :naive_datetime

      timestamps(default: fragment("now()"), null: false)
    end

    create constraint(:lms_curriculum_logs, :lms_curriculum_logs_exam_track_check,
             check: "exam_track IN ('jee_main', 'jee_advanced', 'neet')"
           )

    create constraint(:lms_curriculum_logs, :lms_curriculum_logs_duration_minutes_check,
             check: "duration_minutes > 0 AND duration_minutes <= 720"
           )

    create index(
             :lms_curriculum_logs,
             [:school_code, :program_id, :grade_id, :subject_id, :exam_track],
             where: "deleted_at IS NULL",
             name: :lms_curriculum_logs_active_scope_index
           )

    create index(
             :lms_curriculum_logs,
             [:school_code, :program_id, :grade_id, :subject_id, :exam_track, :log_date],
             where: "deleted_at IS NULL",
             name: :lms_curriculum_logs_active_scope_date_index
           )

    create index(:lms_curriculum_logs, [:log_date], name: :lms_curriculum_logs_log_date_index)

    create table(:lms_curriculum_log_topics) do
      add :curriculum_log_id, references(:lms_curriculum_logs, on_delete: :delete_all),
        null: false

      add :topic_id, references(:topic, on_delete: :nothing), null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:lms_curriculum_log_topics, [:curriculum_log_id, :topic_id],
             name: :lms_curriculum_log_topics_log_topic_unique
           )

    create index(:lms_curriculum_log_topics, [:curriculum_log_id],
             name: :lms_curriculum_log_topics_log_id_index
           )

    create index(:lms_curriculum_log_topics, [:topic_id],
             name: :lms_curriculum_log_topics_topic_id_index
           )

    create table(:lms_curriculum_chapter_completions) do
      add :school_code, :string, size: 255, null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :chapter_id, references(:chapter, on_delete: :nothing), null: false
      add :exam_track, :string, size: 32, null: false
      add :completed_at, :naive_datetime, default: fragment("now()"), null: false
      add :completed_by_email, :string, size: 255
      add :inserted_by_email, :string, size: 255
      add :updated_by_email, :string, size: 255
      add :deleted_at, :naive_datetime

      timestamps(default: fragment("now()"), null: false)
    end

    create constraint(
             :lms_curriculum_chapter_completions,
             :lms_curriculum_chapter_completions_exam_track_check,
             check: "exam_track IN ('jee_main', 'jee_advanced', 'neet')"
           )

    create unique_index(
             :lms_curriculum_chapter_completions,
             [:school_code, :program_id, :chapter_id, :exam_track],
             where: "deleted_at IS NULL",
             name: :lms_curriculum_chapter_completions_active_unique
           )

    create index(
             :lms_curriculum_chapter_completions,
             [:school_code, :program_id, :chapter_id, :exam_track],
             name: :lms_curriculum_chapter_completions_scope_index
           )
  end
end
