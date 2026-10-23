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
           LEFT JOIN "user" ON "user".id = student.user_id
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
  Moves a Transcription Request from `queued` to `running` or `failed`, and from
  `running` to `failed`. Completion happens only through `/draft`.

  The first status post binds the run id; identical replays return the current state
  without writing.
  """
  def update_transcription_request_status(request_key, params) when is_binary(request_key) do
    with {:ok, fields} <- status_fields(params) do
      Repo.transaction(fn -> transition!(request_key, fields) end)
    end
  end

  def update_transcription_request_status(_request_key, _params), do: {:error, :invalid_request}

  @doc """
  Applies etl-next's drafted write-up to the request's Conversation Draft and completes
  the request, atomically.

  The content is written only while the draft is still `transcribing`; a draft the
  Mentor has already discarded or saved is left unchanged and the request still
  completes. A replay by the same run after completion returns `applied: false`.
  """
  def submit_conversation_draft(request_key, params) when is_binary(request_key) do
    with {:ok, draft} <- draft_fields(params) do
      Repo.transaction(fn -> submit_draft!(request_key, draft) end)
    end
  end

  def submit_conversation_draft(_request_key, _params), do: {:error, :invalid_request}

  defp draft_fields(params) when is_map(params) do
    draft = %{
      run_id: params["etl_run_id"],
      transcript_s3_key: params["transcript_s3_key"],
      summary: params["summary"],
      action_items: params["action_items"],
      notes: params["notes"],
      prompt_version: params["prompt_version"],
      model_id: params["model_id"]
    }

    if draft_text?(draft) and list_of?(draft.action_items, &action_item?/1) and
         list_of?(draft.notes, &note?/1),
       do: {:ok, draft},
       else: {:error, :invalid_request}
  end

  defp draft_fields(_params), do: {:error, :invalid_request}

  defp draft_text?(draft) do
    run_id?(draft.run_id) and bounded_string?(draft.transcript_s3_key, 255) and
      nonblank_string?(draft.summary) and bounded_string?(draft.prompt_version, 255) and
      bounded_string?(draft.model_id, 255)
  end

  # Element shapes are validated here, not by the database; unknown keys are rejected.
  defp action_item?(%{"text" => text, "owner" => owner} = item) when map_size(item) == 2,
    do: nonblank_string?(text) and owner in ["student", "mentor", "parent"]

  defp action_item?(_item), do: false

  defp note?(%{"heading" => heading, "points" => points} = note) when map_size(note) == 2,
    do: nonblank_string?(heading) and list_of?(points, &nonblank_string?/1)

  defp note?(_note), do: false

  defp list_of?(values, valid?), do: is_list(values) and Enum.all?(values, valid?)

  defp submit_draft!(request_key, draft) do
    {request_id, state, bound_run_id, _error_code} = lock_request!(request_key)
    {draft_id, draft_state} = lock_draft!(request_id)

    case {state, bound_run_id} do
      {"completed", run_id} when run_id == draft.run_id ->
        draft_response(draft_state, false)

      {_state, run_id} when not is_nil(run_id) and run_id != draft.run_id ->
        Repo.rollback(:etl_run_conflict)

      {state, _run_id} when state in ["completed", "failed"] ->
        Repo.rollback(:terminal_status_conflict)

      {"running", _run_id} ->
        response = apply_draft!(draft_id, draft_state, draft)
        update_request!(request_id, "completed", draft.run_id, nil)
        response

      _queued ->
        Repo.rollback(:invalid_transition)
    end
  end

  defp apply_draft!(draft_id, "transcribing", draft) do
    Repo.query!(
      """
      UPDATE blended_learning_conversation_drafts
      SET state = 'ready', draft_summary = $2, draft_action_items = $3, draft_notes = $4,
          transcript_s3_key = $5, prompt_version = $6, model_id = $7, updated_at = now()
      WHERE id = $1
      """,
      [
        draft_id,
        draft.summary,
        draft.action_items,
        draft.notes,
        draft.transcript_s3_key,
        draft.prompt_version,
        draft.model_id
      ],
      log: false
    )

    draft_response("ready", true)
  end

  defp apply_draft!(_draft_id, draft_state, _draft), do: draft_response(draft_state, false)

  defp draft_response(draft_state, applied),
    do: %{request_state: "completed", draft_state: draft_state, applied: applied}

  defp status_fields(%{"etl_run_id" => run_id, "state" => state} = params) do
    error_code = params["error_code"]

    valid_result =
      case state do
        "running" -> is_nil(error_code)
        "failed" -> bounded_optional_string?(error_code, 64)
        _ -> false
      end

    if run_id?(run_id) and valid_result,
      do: {:ok, {run_id, state, error_code}},
      else: {:error, :invalid_request}
  end

  defp status_fields(_params), do: {:error, :invalid_request}

  defp transition!(request_key, fields) when is_binary(request_key),
    do: request_key |> lock_request!() |> transition!(fields)

  defp transition!({_id, state, run_id, error_code}, {run_id, state, error_code}),
    do: status_response(state, run_id, error_code)

  defp transition!({_id, _state, run_id, _}, {other_run_id, _, _})
       when not is_nil(run_id) and run_id != other_run_id,
       do: Repo.rollback(:etl_run_conflict)

  defp transition!({id, "queued", nil, nil}, {run_id, state, error_code})
       when state in ["running", "failed"],
       do: update_request!(id, state, run_id, error_code)

  defp transition!({id, "running", run_id, nil}, {run_id, "failed", error_code}),
    do: update_request!(id, "failed", run_id, error_code)

  defp transition!({_, state, _, _}, _fields) when state in ["completed", "failed"],
    do: Repo.rollback(:terminal_status_conflict)

  defp transition!(_request, _fields), do: Repo.rollback(:invalid_transition)

  defp update_request!(id, state, run_id, error_code) do
    case Repo.query!(
           """
           UPDATE blended_learning_transcription_requests
           SET state = $2, etl_run_id = $3, error_code = $4, updated_at = now()
           WHERE id = $1
           RETURNING state, etl_run_id, error_code
           """,
           [id, state, run_id, error_code],
           log: false
         ).rows do
      [[state, run_id, error_code]] ->
        if state == "failed", do: fail_transcribing_draft!(id)
        status_response(state, run_id, error_code)

      _ ->
        Repo.rollback(:invalid_request)
    end
  end

  # Only a draft still waiting on this transcription moves to `failed`; a discarded or
  # saved draft is left unchanged.
  defp fail_transcribing_draft!(request_id) do
    {draft_id, draft_state} = lock_draft!(request_id)

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

  # Every machine write locks the request row first, then the draft row.
  defp lock_request!(request_key) do
    case Repo.query!(
           """
           SELECT id, state, etl_run_id, error_code
           FROM blended_learning_transcription_requests
           WHERE request_key = $1
           FOR UPDATE
           """,
           [request_key],
           log: false
         ).rows do
      [[id, state, run_id, error_code]] ->
        {id, state, run_id, error_code}

      [] ->
        Repo.rollback(:transcription_request_not_found)
    end
  end

  # Called only after lock_request!/1 has locked the request row.
  defp lock_draft!(request_id) do
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

    {draft_id, draft_state}
  end

  defp status_response(state, run_id, error_code),
    do: %{state: state, etl_run_id: run_id, error_code: error_code}

  defp run_id?(value), do: bounded_string?(value, 255)

  # Postgres rejects NUL in text and jsonb, so refuse it here as a 422 rather
  # than letting the write fail as a 500.
  defp nonblank_string?(value),
    do: is_binary(value) and String.trim(value) != "" and not String.contains?(value, <<0>>)

  defp bounded_string?(value, maximum),
    do: nonblank_string?(value) and byte_size(value) <= maximum

  defp bounded_optional_string?(nil, _maximum), do: true
  defp bounded_optional_string?(value, maximum), do: bounded_string?(value, maximum)
end
