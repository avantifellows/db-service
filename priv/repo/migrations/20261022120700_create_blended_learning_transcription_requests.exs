defmodule Dbservice.Repo.Migrations.CreateBlendedLearningTranscriptionRequests do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Transcription
  # Requests directly over SQL, retries included. etl-next reads a request and moves it
  # through its states only through the db-service machine API. etl-next binds `etl_run_id`
  # with its first status post (`running` or `failed`); the id is derived from the request
  # key.
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

      add :requested_by_email, :string, size: 255, null: false
      add :state, :string, null: false, default: "queued"
      add :etl_run_id, :string
      add :error_code, :string

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

    create constraint(@table, :bl_transcription_requests_state_metadata_check,
             check: """
             (state = 'queued' AND etl_run_id IS NULL AND error_code IS NULL)
             OR (state IN ('running', 'completed') AND etl_run_id IS NOT NULL AND error_code IS NULL)
             OR (state = 'failed' AND etl_run_id IS NOT NULL)
             """
           )

    create constraint(@table, :bl_transcription_requests_safe_error_check,
             check: "error_code IS NULL OR char_length(error_code) BETWEEN 1 AND 64"
           )

    create constraint(@table, :bl_transcription_requests_requested_by_email_check,
             check: "requested_by_email ~ '[^[:space:]]'"
           )
  end
end
