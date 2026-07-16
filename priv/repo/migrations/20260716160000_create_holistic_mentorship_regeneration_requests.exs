defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipRegenerationRequests do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_regeneration_requests) do
      add :request_key, :string, null: false
      add :requested_by_user_id, references(:user, on_delete: :nothing), null: false
      add :student_id, references(:student, on_delete: :nothing), null: false

      add :prompt_configuration_id,
          references(:holistic_mentorship_prompt_configurations, on_delete: :nothing),
          null: false

      add :force, :boolean, null: false, default: false
      add :state, :string, null: false, default: "queued"
      add :etl_run_id, :string
      add :error_code, :string
      add :error_message, :text

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:holistic_mentorship_regeneration_requests, [:request_key],
             name: :hm_regeneration_requests_key_unique
           )

    create constraint(
             :holistic_mentorship_regeneration_requests,
             :hm_regeneration_requests_state_check,
             check: "state IN ('queued', 'running', 'completed', 'failed')"
           )

    create constraint(
             :holistic_mentorship_regeneration_requests,
             :hm_regeneration_requests_state_metadata_check,
             check: """
             (state = 'queued' AND etl_run_id IS NULL AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'running' AND etl_run_id IS NOT NULL
                 AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'completed' AND etl_run_id IS NOT NULL
                 AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'failed' AND etl_run_id IS NOT NULL)
             """
           )

    create constraint(
             :holistic_mentorship_regeneration_requests,
             :hm_regeneration_requests_safe_error_check,
             check: """
             (error_code IS NULL OR char_length(error_code) BETWEEN 1 AND 64)
             AND (error_message IS NULL OR char_length(error_message) BETWEEN 1 AND 500)
             """
           )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_protect_regeneration_request_identity()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.request_key IS DISTINCT FROM OLD.request_key
          OR NEW.requested_by_user_id IS DISTINCT FROM OLD.requested_by_user_id
          OR NEW.student_id IS DISTINCT FROM OLD.student_id
          OR NEW.prompt_configuration_id IS DISTINCT FROM OLD.prompt_configuration_id
          OR NEW.force IS DISTINCT FROM OLD.force
        THEN
          RAISE EXCEPTION 'Regeneration Request identity is immutable' USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION IF EXISTS holistic_mentorship_protect_regeneration_request_identity()"
    )

    execute(
      """
      CREATE TRIGGER hm_regeneration_requests_identity_immutable
      BEFORE UPDATE ON holistic_mentorship_regeneration_requests
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_protect_regeneration_request_identity()
      """,
      "DROP TRIGGER IF EXISTS hm_regeneration_requests_identity_immutable ON holistic_mentorship_regeneration_requests"
    )
  end
end
