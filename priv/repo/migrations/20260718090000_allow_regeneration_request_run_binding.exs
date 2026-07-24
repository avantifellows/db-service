defmodule Dbservice.Repo.Migrations.AllowRegenerationRequestRunBinding do
  use Ecto.Migration

  def up do
    drop constraint(
           :holistic_mentorship_regeneration_requests,
           :hm_regeneration_requests_state_metadata_check
         )

    create constraint(
             :holistic_mentorship_regeneration_requests,
             :hm_regeneration_requests_state_metadata_check,
             check: """
             (state = 'queued' AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'running' AND etl_run_id IS NOT NULL
                 AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'completed' AND etl_run_id IS NOT NULL
                 AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'failed' AND etl_run_id IS NOT NULL)
             """
           )
  end

  def down do
    drop constraint(
           :holistic_mentorship_regeneration_requests,
           :hm_regeneration_requests_state_metadata_check
         )

    create constraint(
             :holistic_mentorship_regeneration_requests,
             :hm_regeneration_requests_state_metadata_check,
             check: """
             (state = 'queued' AND etl_run_id IS NULL
                 AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'running' AND etl_run_id IS NOT NULL
                 AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'completed' AND etl_run_id IS NOT NULL
                 AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'failed' AND etl_run_id IS NOT NULL)
             """
           )
  end
end
