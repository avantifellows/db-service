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

  @doc """
  Moves a Transcription Request through `queued -> running -> completed | failed`,
  following `Dbservice.HolisticMentorship.update_regeneration_request_status/2`.

  The first etl-next run to report binds its `etl_run_id`; identical replays return
  the current state without writing.
  """
  def update_transcription_request_status(request_key, params) when is_binary(request_key) do
    with {:ok, fields} <- status_fields(params) do
      Repo.transaction(fn -> transition!(request_key, fields) end)
    end
  end

  def update_transcription_request_status(_request_key, _params), do: {:error, :invalid_request}

  defp status_fields(%{"etl_run_id" => run_id, "state" => state} = params) do
    error_code = params["error_code"]
    error_message = params["error_message"]

    valid_result =
      case state do
        state when state in ["queued", "running", "completed"] ->
          is_nil(error_code) and is_nil(error_message)

        "failed" ->
          bounded_optional_string?(error_code, 64) and
            bounded_optional_string?(error_message, 500)

        _ ->
          false
      end

    if nonblank_string?(run_id) and byte_size(run_id) <= 255 and valid_result,
      do: {:ok, {run_id, state, error_code, error_message}},
      else: {:error, :invalid_request}
  end

  defp status_fields(_params), do: {:error, :invalid_request}

  defp transition!(request_key, fields) when is_binary(request_key) do
    case Repo.query!(
           """
           SELECT id, state, etl_run_id, error_code, error_message
           FROM blended_learning_transcription_requests
           WHERE request_key = $1
           FOR UPDATE
           """,
           [request_key],
           log: false
         ).rows do
      [[id, state, run_id, error_code, error_message]] ->
        transition!({id, state, run_id, error_code, error_message}, fields)

      [] ->
        Repo.rollback(:transcription_request_not_found)
    end
  end

  defp transition!(
         {_id, state, run_id, error_code, error_message},
         {run_id, state, error_code, error_message}
       ),
       do: status_response(state, run_id, error_code, error_message)

  defp transition!({_id, _state, run_id, _, _}, {other_run_id, _, _, _})
       when not is_nil(run_id) and run_id != other_run_id,
       do: Repo.rollback(:etl_run_conflict)

  defp transition!({id, "queued", nil, nil, nil}, {run_id, "queued", nil, nil}),
    do: update_request!(id, "queued", run_id, nil, nil)

  defp transition!({id, "queued", nil, nil, nil}, {run_id, "running", nil, nil}),
    do: update_request!(id, "running", run_id, nil, nil)

  defp transition!({id, "queued", run_id, nil, nil}, {run_id, "running", nil, nil}),
    do: update_request!(id, "running", run_id, nil, nil)

  defp transition!(
         {id, "queued", run_id, nil, nil},
         {run_id, "failed", error_code, error_message}
       ),
       do: update_request!(id, "failed", run_id, error_code, error_message)

  defp transition!({id, "running", run_id, nil, nil}, {run_id, state, error_code, error_message})
       when state in ["completed", "failed"],
       do: update_request!(id, state, run_id, error_code, error_message)

  defp transition!({_, state, _, _, _}, _fields) when state in ["completed", "failed"],
    do: Repo.rollback(:terminal_status_conflict)

  defp transition!(_request, _fields), do: Repo.rollback(:invalid_transition)

  defp update_request!(id, state, run_id, error_code, error_message) do
    case Repo.query!(
           """
           UPDATE blended_learning_transcription_requests
           SET state = $2, etl_run_id = $3, error_code = $4, error_message = $5,
               updated_at = now()
           WHERE id = $1
           RETURNING state, etl_run_id, error_code, error_message
           """,
           [id, state, run_id, error_code, error_message],
           log: false
         ).rows do
      [[state, run_id, error_code, error_message]] ->
        if state == "failed", do: fail_transcribing_draft!(id)
        status_response(state, run_id, error_code, error_message)

      _ ->
        Repo.rollback(:invalid_request)
    end
  end

  # The request row is already locked, so the lock order is always request, then draft.
  # Only a draft still waiting on this transcription moves to `failed`; a discarded or
  # saved draft is left unchanged.
  defp fail_transcribing_draft!(request_id) do
    [[draft_id, draft_state]] =
      Repo.query!(
        """
        SELECT draft.id, draft.state
        FROM blended_learning_conversation_drafts AS draft
        JOIN blended_learning_transcription_requests AS request ON request.draft_id = draft.id
        WHERE request.id = $1
        FOR UPDATE OF draft
        """,
        [request_id],
        log: false
      ).rows

    if draft_state == "transcribing" do
      Repo.query!(
        """
        UPDATE blended_learning_conversation_drafts
        SET state = 'failed', updated_at = now()
        WHERE id = $1
        """,
        [draft_id],
        log: false
      )
    end
  end

  defp status_response(state, run_id, error_code, error_message) do
    %{state: state, etl_run_id: run_id, error_code: error_code, error_message: error_message}
  end

  defp nonblank_string?(value), do: is_binary(value) and String.trim(value) != ""

  defp bounded_optional_string?(nil, _maximum), do: true

  defp bounded_optional_string?(value, maximum),
    do: nonblank_string?(value) and byte_size(value) <= maximum
end
