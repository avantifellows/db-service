defmodule Dbservice.BlendedLearning.TranscriptionRequests do
  @moduledoc """
  The etl-next machine contract for Blended Learning Transcription Requests.

  af_lms creates requests directly over SQL; etl-next has no Postgres access and
  reads a request through this module. Reads carry the draft's session details
  and the Student's gender only, never names, phones or other PII.

  Queries are schemaless raw SQL with `log: false`, matching
  `Dbservice.HolisticMentorship`, so request keys and draft content stay out of
  the logs.
  """

  alias Dbservice.Repo

  def get_transcription_request(request_key) when is_binary(request_key) do
    case Repo.query!(
           """
           SELECT request.request_key, request.state, request.etl_run_id, request.error_code,
                  draft.id, draft.state, draft.occurred_on, draft.mode, draft.spoke_with,
                  draft.duration_minutes, draft.call_recording_s3_key,
                  draft.recording_content_type, student.id, "user".gender
           FROM blended_learning_transcription_requests AS request
           JOIN blended_learning_conversation_drafts AS draft
             ON draft.id = request.draft_id AND draft.student_id = request.student_id
           JOIN student ON student.id = request.student_id
           JOIN "user" ON "user".id = student.user_id
           WHERE request.request_key = $1
           """,
           [request_key],
           log: false
         ).rows do
      [
        [
          request_key,
          state,
          etl_run_id,
          error_code,
          draft_id,
          draft_state,
          occurred_on,
          mode,
          spoke_with,
          duration_minutes,
          call_recording_s3_key,
          recording_content_type,
          student_id,
          gender
        ]
      ] ->
        {:ok,
         %{
           request_key: request_key,
           state: state,
           etl_run_id: etl_run_id,
           error_code: error_code,
           draft: %{
             id: draft_id,
             state: draft_state,
             occurred_on: occurred_on,
             mode: mode,
             spoke_with: spoke_with,
             duration_minutes: duration_minutes,
             call_recording_s3_key: call_recording_s3_key,
             recording_content_type: recording_content_type
           },
           student: %{id: student_id, gender: gender}
         }}

      [] ->
        {:error, :transcription_request_not_found}
    end
  end

  def get_transcription_request(_request_key), do: {:error, :transcription_request_not_found}
end
