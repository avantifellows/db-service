defmodule Dbservice.Repo.Migrations.CreateBlendedLearningTranscriptionRequests do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Transcription
  # Requests directly over SQL, retries included. etl-next reads a request and moves it
  # through its states only through the db-service machine API. The table follows the
  # Holistic Regeneration Request after its run-binding migrations.
  #
  # Blended Learning migration 8 of 8.

  @table :blended_learning_transcription_requests
  @drafts :blended_learning_conversation_drafts

  def change do
    create table(@table) do
      add :request_key, :string, null: false

      add :draft_id,
          references(@drafts, with: [student_id: :student_id], on_delete: :nothing),
          null: false

      add :student_id, references(:student, on_delete: :nothing), null: false

      add :requested_by_user_id,
          references(:user,
            name: :bl_transcription_requests_requested_by_user_id_fkey,
            on_delete: :nothing
          )

      add :requested_by_email, :string, size: 255, null: false
      add :state, :string, null: false, default: "queued"
      add :etl_run_id, :string
      add :error_code, :string
      add :error_message, :text

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(@table, [:request_key], name: :bl_transcription_requests_key_unique)

    create unique_index(@table, [:draft_id],
             name: :bl_transcription_requests_active_draft_unique,
             where: "state IN ('queued', 'running')"
           )

    create constraint(@table, :bl_transcription_requests_state_check,
             check: "state IN ('queued', 'running', 'completed', 'failed')"
           )

    # The run-binding version: a queued request may already carry its bound etl_run_id.
    create constraint(@table, :bl_transcription_requests_state_metadata_check,
             check: """
             (state = 'queued' AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'running' AND etl_run_id IS NOT NULL
                 AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'completed' AND etl_run_id IS NOT NULL
                 AND error_code IS NULL AND error_message IS NULL)
             OR (state = 'failed' AND etl_run_id IS NOT NULL)
             """
           )

    create constraint(@table, :bl_transcription_requests_safe_error_check,
             check: """
             (error_code IS NULL OR char_length(error_code) BETWEEN 1 AND 64)
             AND (error_message IS NULL OR char_length(error_message) BETWEEN 1 AND 500)
             """
           )

    create constraint(@table, :bl_transcription_requests_requested_by_email_check,
             check: "requested_by_email ~ '[^[:space:]]'"
           )

    execute(
      """
      CREATE FUNCTION blended_learning_protect_transcription_request_identity()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.request_key IS DISTINCT FROM OLD.request_key
          OR NEW.draft_id IS DISTINCT FROM OLD.draft_id
          OR NEW.student_id IS DISTINCT FROM OLD.student_id
          OR NEW.requested_by_user_id IS DISTINCT FROM OLD.requested_by_user_id
          OR NEW.requested_by_email IS DISTINCT FROM OLD.requested_by_email
          OR (OLD.etl_run_id IS NOT NULL AND NEW.etl_run_id IS DISTINCT FROM OLD.etl_run_id)
        THEN
          RAISE EXCEPTION 'Transcription Request identity is immutable' USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION blended_learning_protect_transcription_request_identity()"
    )

    execute(
      """
      CREATE TRIGGER bl_transcription_requests_identity_immutable
      BEFORE UPDATE ON blended_learning_transcription_requests
      FOR EACH ROW EXECUTE FUNCTION blended_learning_protect_transcription_request_identity()
      """,
      "DROP TRIGGER bl_transcription_requests_identity_immutable ON blended_learning_transcription_requests"
    )
  end
end
