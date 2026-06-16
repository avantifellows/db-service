defmodule Dbservice.Repo.Migrations.CreateAcademicMentorshipTables do
  use Ecto.Migration

  def change do
    create table(:acad_mentorship_runtime_settings, primary_key: false) do
      add :id, :string, primary_key: true, default: "global"
      add :provider, :string
      add :model, :string
      add :scoring_model, :string
      add :concurrency, :integer
      add :timeout_seconds, :float
      add :validation_timeout_seconds, :float
      add :pi_version, :string
      add :pi_output_mode, :string
      add :pi_thinking_level, :string
      add :pi_tool_allowlist, :map

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_runtime_settings, :am_runtime_settings_singleton_check,
             check: "id = 'global'"
           )

    create constraint(:acad_mentorship_runtime_settings, :am_runtime_settings_numeric_check,
             check:
               "(concurrency IS NULL OR concurrency >= 1) AND (timeout_seconds IS NULL OR timeout_seconds >= 0) AND (validation_timeout_seconds IS NULL OR validation_timeout_seconds >= 0)"
           )

    create table(:acad_mentorship_prompt_versions, primary_key: false) do
      identity_primary_key()

      add :prompt_type, :string, null: false
      add :version_number, :integer, null: false
      add :title, :string
      add :description, :text
      add :content, :text, null: false
      add :is_active, :boolean, default: true, null: false
      add :deleted_at, :utc_datetime

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_prompt_versions, :am_prompt_versions_type_check,
             check: "prompt_type IN ('pipeline', 'validation', 'scoring')"
           )

    create constraint(:acad_mentorship_prompt_versions, :am_prompt_versions_version_check,
             check: "version_number >= 1"
           )

    create unique_index(:acad_mentorship_prompt_versions, [:prompt_type, :version_number],
             name: :am_prompt_versions_type_version_unique
           )

    create unique_index(:acad_mentorship_prompt_versions, [:prompt_type],
             where: "is_active IS TRUE AND deleted_at IS NULL",
             name: :am_prompt_versions_one_active
           )

    create table(:acad_mentorship_tests_to_consider, primary_key: false) do
      identity_primary_key()

      add :program_id, references(:program, on_delete: :nothing), null: false
      add :test_id, :string, null: false
      add :test_name, :string
      add :deleted_at, :utc_datetime

      created_updated_timestamps()
    end

    create index(:acad_mentorship_tests_to_consider, [:program_id],
             name: :am_tests_to_consider_program_idx
           )

    create index(:acad_mentorship_tests_to_consider, [:test_id],
             name: :am_tests_to_consider_test_idx
           )

    create unique_index(:acad_mentorship_tests_to_consider, [:program_id, :test_id],
             where: "deleted_at IS NULL",
             name: :am_tests_to_consider_active_unique
           )

    create table(:acad_mentorship_teacher_feedback, primary_key: false) do
      identity_primary_key()

      add :student_id, references(:student, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :test_id, :string, null: false
      add :test_name, :string
      add :mentor_user_id, references(:user, on_delete: :nothing)
      add :mentor_name_text, :string
      add :feedback, :map, null: false
      add :deleted_at, :utc_datetime

      created_updated_timestamps()
    end

    create index(:acad_mentorship_teacher_feedback, [:student_id],
             name: :am_teacher_feedback_student_idx
           )

    create index(:acad_mentorship_teacher_feedback, [:program_id],
             name: :am_teacher_feedback_program_idx
           )

    create index(:acad_mentorship_teacher_feedback, [:test_id],
             name: :am_teacher_feedback_test_idx
           )

    create index(:acad_mentorship_teacher_feedback, [:mentor_user_id],
             name: :am_teacher_feedback_mentor_idx
           )

    create unique_index(:acad_mentorship_teacher_feedback, [:student_id, :program_id, :test_id],
             where: "deleted_at IS NULL",
             name: :am_teacher_feedback_active_unique
           )

    create table(:acad_mentorship_cutoff_rows, primary_key: false) do
      identity_primary_key()

      add :category, :string, null: false
      add :exam, :string, null: false
      add :qualification_cutoff, :integer, null: false
      add :nit_cutoff, :integer, null: false

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_cutoff_rows, :am_cutoff_rows_scores_check,
             check: "qualification_cutoff >= 0 AND nit_cutoff >= 0"
           )

    create unique_index(:acad_mentorship_cutoff_rows, [:category, :exam],
             name: :am_cutoff_rows_category_exam_unique
           )

    create table(:acad_mentorship_benchmark_students, primary_key: false) do
      identity_primary_key()

      add :student_id, references(:student, on_delete: :nothing), null: false
      add :program_id, references(:program, on_delete: :nothing), null: false
      add :reason, :text
      add :benchmark_label, :string
      add :is_active, :boolean, default: true, null: false

      created_updated_timestamps()
    end

    create index(:acad_mentorship_benchmark_students, [:student_id],
             name: :am_benchmark_students_student_idx
           )

    create index(:acad_mentorship_benchmark_students, [:program_id],
             name: :am_benchmark_students_program_idx
           )

    create unique_index(:acad_mentorship_benchmark_students, [:student_id, :program_id],
             where: "is_active IS TRUE",
             name: :am_benchmark_students_active_unique
           )

    create table(:acad_mentorship_reference_reports, primary_key: false) do
      identity_primary_key()

      add :benchmark_student_id,
          references(:acad_mentorship_benchmark_students, on_delete: :nothing),
          null: false

      add :version_number, :integer, null: false
      add :s3_key, :text, null: false
      add :status, :string, default: "draft", null: false
      add :approved_at, :utc_datetime

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_reference_reports, :am_reference_reports_status_check,
             check: "status IN ('draft', 'approved', 'archived')"
           )

    create constraint(:acad_mentorship_reference_reports, :am_reference_reports_version_check,
             check: "version_number >= 1"
           )

    create index(:acad_mentorship_reference_reports, [:benchmark_student_id],
             name: :am_reference_reports_benchmark_idx
           )

    create unique_index(
             :acad_mentorship_reference_reports,
             [:benchmark_student_id, :version_number],
             name: :am_reference_reports_benchmark_version_unique
           )

    create unique_index(:acad_mentorship_reference_reports, [:s3_key],
             name: :am_reference_reports_s3_key_unique
           )

    create unique_index(:acad_mentorship_reference_reports, [:benchmark_student_id],
             where: "status = 'approved'",
             name: :am_reference_reports_one_approved
           )

    create table(:acad_mentorship_inference_sessions, primary_key: false) do
      identity_primary_key()

      add :program_id, references(:program, on_delete: :nothing)
      add :status, :string, default: "created", null: false
      add :is_eval, :boolean, default: false, null: false

      add :pipeline_prompt_version_id,
          references(:acad_mentorship_prompt_versions,
            on_delete: :nothing,
            name: :am_sessions_pipeline_prompt_fkey
          )

      add :validation_prompt_version_id,
          references(:acad_mentorship_prompt_versions,
            on_delete: :nothing,
            name: :am_sessions_validation_prompt_fkey
          )

      add :config_snapshot_json, :text
      add :error_type, :string
      add :error_message, :text
      add :started_at, :utc_datetime
      add :cancel_requested_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :deleted_at, :utc_datetime

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_inference_sessions, :am_sessions_status_check,
             check:
               "status IN ('created', 'running', 'completed', 'completed_with_errors', 'errored', 'cancelled')"
           )

    create index(:acad_mentorship_inference_sessions, [:program_id],
             name: :am_sessions_program_idx
           )

    create index(:acad_mentorship_inference_sessions, [:status], name: :am_sessions_status_idx)

    create index(:acad_mentorship_inference_sessions, [:is_eval], name: :am_sessions_is_eval_idx)

    create index(:acad_mentorship_inference_sessions, [:created_at, :id],
             name: :am_sessions_created_id_idx
           )

    create index(:acad_mentorship_inference_sessions, [:pipeline_prompt_version_id],
             name: :am_sessions_pipeline_prompt_idx
           )

    create index(:acad_mentorship_inference_sessions, [:validation_prompt_version_id],
             name: :am_sessions_validation_prompt_idx
           )

    create table(:acad_mentorship_inference_items, primary_key: false) do
      identity_primary_key()

      add :session_id,
          references(:acad_mentorship_inference_sessions, on_delete: :nothing),
          null: false

      add :student_id, references(:student, on_delete: :nothing), null: false
      add :status, :string, default: "created", null: false
      add :current_step, :string
      add :latest_test_id, :string
      add :selected_test_ids, :map
      add :pipeline_prompt_tokens, :integer, default: 0, null: false
      add :pipeline_completion_tokens, :integer, default: 0, null: false
      add :pipeline_total_tokens, :integer, default: 0, null: false
      add :validation_prompt_tokens, :integer, default: 0, null: false
      add :validation_completion_tokens, :integer, default: 0, null: false
      add :validation_total_tokens, :integer, default: 0, null: false
      add :pipeline_cost_usd, :float, default: 0.0, null: false
      add :validation_cost_usd, :float, default: 0.0, null: false
      add :validation_verdict, :string
      add :error_message, :text
      add :error_type, :string
      add :no_data_reason, :string
      add :is_retry, :boolean, default: false, null: false
      add :retry_of_item_id, references(:acad_mentorship_inference_items, on_delete: :nothing)
      add :duration_ms, :integer
      add :started_at, :utc_datetime
      add :last_progress_at, :utc_datetime
      add :completed_at, :utc_datetime

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_inference_items, :am_items_status_check,
             check:
               "status IN ('created', 'running', 'completed', 'errored', 'no_data', 'validation_failed', 'cancelled')"
           )

    create constraint(:acad_mentorship_inference_items, :am_items_validation_verdict_check,
             check:
               "validation_verdict IS NULL OR validation_verdict IN ('PASS', 'FAIL', 'PASS WITH WARNINGS')"
           )

    create constraint(:acad_mentorship_inference_items, :am_items_token_counts_check,
             check:
               "pipeline_prompt_tokens >= 0 AND pipeline_completion_tokens >= 0 AND pipeline_total_tokens >= 0 AND validation_prompt_tokens >= 0 AND validation_completion_tokens >= 0 AND validation_total_tokens >= 0"
           )

    create constraint(:acad_mentorship_inference_items, :am_items_costs_check,
             check: "pipeline_cost_usd >= 0 AND validation_cost_usd >= 0"
           )

    create constraint(:acad_mentorship_inference_items, :am_items_duration_check,
             check: "duration_ms IS NULL OR duration_ms >= 0"
           )

    create index(:acad_mentorship_inference_items, [:session_id], name: :am_items_session_idx)

    create index(:acad_mentorship_inference_items, [:student_id], name: :am_items_student_idx)

    create index(:acad_mentorship_inference_items, [:status], name: :am_items_status_idx)

    create index(:acad_mentorship_inference_items, [:latest_test_id],
             name: :am_items_latest_test_idx
           )

    create index(:acad_mentorship_inference_items, [:retry_of_item_id],
             name: :am_items_retry_of_idx
           )

    create index(:acad_mentorship_inference_items, [:created_at, :id],
             name: :am_items_created_id_idx
           )

    create unique_index(:acad_mentorship_inference_items, [:session_id, :student_id],
             where: "is_retry IS FALSE",
             name: :am_items_original_student_unique
           )

    create table(:acad_mentorship_inference_item_files, primary_key: false) do
      identity_primary_key()

      add :item_id,
          references(:acad_mentorship_inference_items, on_delete: :delete_all),
          null: false

      add :logical_path, :text, null: false
      add :file_kind, :string, default: "workspace_file", null: false
      add :s3_key, :text, null: false
      add :mime_type, :string, null: false
      add :byte_size, :bigint, null: false
      add :sha256, :string
      add :uploaded_at, :utc_datetime, default: fragment("now()"), null: false
    end

    create constraint(:acad_mentorship_inference_item_files, :am_item_files_byte_size_check,
             check: "byte_size >= 0"
           )

    create index(:acad_mentorship_inference_item_files, [:item_id], name: :am_item_files_item_idx)

    create index(:acad_mentorship_inference_item_files, [:logical_path],
             name: :am_item_files_logical_path_idx
           )

    create index(:acad_mentorship_inference_item_files, [:file_kind],
             name: :am_item_files_file_kind_idx
           )

    create index(:acad_mentorship_inference_item_files, [:item_id, :file_kind],
             name: :am_item_files_item_kind_idx
           )

    create unique_index(:acad_mentorship_inference_item_files, [:item_id, :logical_path],
             name: :am_item_files_item_path_unique
           )

    create unique_index(:acad_mentorship_inference_item_files, [:s3_key],
             name: :am_item_files_s3_key_unique
           )

    create table(:acad_mentorship_scoring_criteria, primary_key: false) do
      identity_primary_key()

      add :criterion_key, :string, null: false
      add :version_number, :integer, default: 1, null: false
      add :name, :string, null: false
      add :description, :text, null: false
      add :weight, :float, default: 1.0, null: false
      add :sort_order, :integer, default: 0, null: false
      add :is_active, :boolean, default: true, null: false

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_scoring_criteria, :am_scoring_criteria_values_check,
             check: "version_number >= 1 AND weight >= 0"
           )

    create unique_index(:acad_mentorship_scoring_criteria, [:criterion_key, :version_number],
             name: :am_scoring_criteria_key_version_unique
           )

    create unique_index(:acad_mentorship_scoring_criteria, [:criterion_key],
             where: "is_active IS TRUE",
             name: :am_scoring_criteria_one_active
           )

    create index(:acad_mentorship_scoring_criteria, [:sort_order],
             name: :am_scoring_criteria_sort_order_idx
           )

    create table(:acad_mentorship_eval_runs, primary_key: false) do
      identity_primary_key()

      add :session_id,
          references(:acad_mentorship_inference_sessions, on_delete: :nothing),
          null: false

      add :status, :string, default: "created", null: false

      add :scoring_prompt_version_id,
          references(:acad_mentorship_prompt_versions, on_delete: :nothing)

      add :config_snapshot_json, :text
      add :error_type, :string
      add :error_message, :text
      add :completed_at, :utc_datetime

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_eval_runs, :am_eval_runs_status_check,
             check:
               "status IN ('created', 'pipeline_running', 'scoring', 'completed', 'completed_with_errors', 'errored', 'cancelled')"
           )

    create unique_index(:acad_mentorship_eval_runs, [:session_id],
             name: :am_eval_runs_session_unique
           )

    create index(:acad_mentorship_eval_runs, [:status], name: :am_eval_runs_status_idx)

    create index(:acad_mentorship_eval_runs, [:created_at, :id],
             name: :am_eval_runs_created_id_idx
           )

    create index(:acad_mentorship_eval_runs, [:scoring_prompt_version_id],
             name: :am_eval_runs_scoring_prompt_idx
           )

    create table(:acad_mentorship_eval_run_benchmarks, primary_key: false) do
      identity_primary_key()

      add :eval_run_id, references(:acad_mentorship_eval_runs, on_delete: :delete_all),
        null: false

      add :benchmark_student_id,
          references(:acad_mentorship_benchmark_students, on_delete: :nothing),
          null: false

      add :reference_report_id,
          references(:acad_mentorship_reference_reports, on_delete: :nothing)

      add :scored_item_id, references(:acad_mentorship_inference_items, on_delete: :nothing)
      add :scoring_status, :string, default: "pending", null: false
      add :scoring_error, :text
      add :scoring_attempt_count, :integer, default: 0, null: false
      add :scoring_prompt_tokens, :integer, default: 0, null: false
      add :scoring_completion_tokens, :integer, default: 0, null: false
      add :scoring_total_tokens, :integer, default: 0, null: false
      add :scoring_cost_usd, :float, default: 0.0, null: false
      add :scoring_started_at, :utc_datetime
      add :scoring_completed_at, :utc_datetime

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_eval_run_benchmarks, :am_eval_benchmarks_status_check,
             check: "scoring_status IN ('pending', 'scored', 'skipped', 'errored')"
           )

    create constraint(:acad_mentorship_eval_run_benchmarks, :am_eval_benchmarks_counts_check,
             check:
               "scoring_attempt_count >= 0 AND scoring_prompt_tokens >= 0 AND scoring_completion_tokens >= 0 AND scoring_total_tokens >= 0 AND scoring_cost_usd >= 0"
           )

    create unique_index(
             :acad_mentorship_eval_run_benchmarks,
             [:eval_run_id, :benchmark_student_id],
             name: :am_eval_benchmarks_run_student_unique
           )

    create index(:acad_mentorship_eval_run_benchmarks, [:eval_run_id],
             name: :am_eval_benchmarks_run_idx
           )

    create index(:acad_mentorship_eval_run_benchmarks, [:benchmark_student_id],
             name: :am_eval_benchmarks_student_idx
           )

    create index(:acad_mentorship_eval_run_benchmarks, [:reference_report_id],
             name: :am_eval_benchmarks_reference_idx
           )

    create index(:acad_mentorship_eval_run_benchmarks, [:scored_item_id],
             name: :am_eval_benchmarks_item_idx
           )

    create index(:acad_mentorship_eval_run_benchmarks, [:scoring_status],
             name: :am_eval_benchmarks_status_idx
           )

    create table(:acad_mentorship_eval_run_scoring_criteria, primary_key: false) do
      identity_primary_key()

      add :eval_run_id, references(:acad_mentorship_eval_runs, on_delete: :delete_all),
        null: false

      add :scoring_criterion_id,
          references(:acad_mentorship_scoring_criteria,
            on_delete: :nothing,
            name: :am_eval_run_criteria_criterion_fkey
          ),
          null: false

      add :created_at, :utc_datetime, default: fragment("now()"), null: false
    end

    create unique_index(
             :acad_mentorship_eval_run_scoring_criteria,
             [:eval_run_id, :scoring_criterion_id],
             name: :am_eval_run_criteria_unique
           )

    create index(:acad_mentorship_eval_run_scoring_criteria, [:eval_run_id],
             name: :am_eval_run_criteria_run_idx
           )

    create index(:acad_mentorship_eval_run_scoring_criteria, [:scoring_criterion_id],
             name: :am_eval_run_criteria_criterion_idx
           )

    create table(:acad_mentorship_eval_scores, primary_key: false) do
      identity_primary_key()

      add :eval_run_benchmark_id,
          references(:acad_mentorship_eval_run_benchmarks, on_delete: :delete_all),
          null: false

      add :eval_run_id, references(:acad_mentorship_eval_runs, on_delete: :delete_all)
      add :item_id, references(:acad_mentorship_inference_items, on_delete: :nothing), null: false

      add :scoring_criterion_id,
          references(:acad_mentorship_scoring_criteria, on_delete: :nothing),
          null: false

      add :score, :integer, null: false
      add :justification, :text, null: false
      add :human_score, :integer
      add :human_justification, :text
      add :is_superseded, :boolean, default: false, null: false

      created_updated_timestamps()
    end

    create constraint(:acad_mentorship_eval_scores, :am_eval_scores_score_check,
             check:
               "score BETWEEN 1 AND 5 AND (human_score IS NULL OR human_score BETWEEN 1 AND 5)"
           )

    create index(:acad_mentorship_eval_scores, [:eval_run_benchmark_id],
             name: :am_eval_scores_benchmark_idx
           )

    create index(:acad_mentorship_eval_scores, [:eval_run_id], name: :am_eval_scores_run_idx)

    create index(:acad_mentorship_eval_scores, [:item_id], name: :am_eval_scores_item_idx)

    create index(:acad_mentorship_eval_scores, [:scoring_criterion_id],
             name: :am_eval_scores_criterion_idx
           )

    create unique_index(
             :acad_mentorship_eval_scores,
             [:eval_run_benchmark_id, :scoring_criterion_id],
             where: "is_superseded IS FALSE",
             name: :am_eval_scores_active_unique
           )
  end

  defp identity_primary_key do
    add :id, :identity, primary_key: true
  end

  defp created_updated_timestamps do
    add :created_at, :utc_datetime, default: fragment("now()"), null: false
    add :updated_at, :utc_datetime, default: fragment("now()"), null: false
  end
end
