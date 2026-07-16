defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipProfileGenerationStatuses do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_profile_generation_statuses) do
      add :etl_run_id, :string, null: false
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :form_id, :string, null: false
      add :af_session_id, :string, null: false
      add :entry_grade, :integer, null: false

      add :prompt_configuration_id,
          references(:holistic_mentorship_prompt_configurations, on_delete: :nothing),
          null: false

      add :state, :string, null: false
      add :completed_outcome, :string
      add :error_code, :string
      add :error_message, :string

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(
             :holistic_mentorship_profile_generation_statuses,
             [
               :etl_run_id,
               :student_id,
               :form_id,
               :af_session_id,
               :entry_grade,
               :prompt_configuration_id
             ],
             name: :hm_profile_generation_statuses_identity_unique
           )

    create constraint(
             :holistic_mentorship_profile_generation_statuses,
             :hm_profile_generation_statuses_source_check,
             check: """
             (form_id = '6a44a83d1184e717b920c499'
              AND af_session_id = 'EnableStudents_6a44a83d1184e717b920c499'
              AND entry_grade = 11)
             OR
             (form_id = '6a4deca8e030ebe34669fb0f'
              AND af_session_id = 'EnableStudents_6a4deca8e030ebe34669fb0f'
              AND entry_grade = 12)
             """
           )

    create constraint(
             :holistic_mentorship_profile_generation_statuses,
             :hm_profile_generation_statuses_state_check,
             check: "state IN ('queued', 'running', 'completed', 'failed')"
           )

    create constraint(
             :holistic_mentorship_profile_generation_statuses,
             :hm_profile_generation_statuses_result_check,
             check: """
             (state = 'completed'
              AND completed_outcome IN ('published', 'replaced', 'unchanged')
              AND error_code IS NULL AND error_message IS NULL)
             OR
             (state = 'failed' AND completed_outcome IS NULL)
             OR
             (state IN ('queued', 'running') AND completed_outcome IS NULL
              AND error_code IS NULL AND error_message IS NULL)
             """
           )

    create constraint(
             :holistic_mentorship_profile_generation_statuses,
             :hm_profile_generation_statuses_safe_error_check,
             check: """
             (error_code IS NULL OR char_length(error_code) BETWEEN 1 AND 64)
             AND (error_message IS NULL OR char_length(error_message) BETWEEN 1 AND 500)
             """
           )
  end
end
