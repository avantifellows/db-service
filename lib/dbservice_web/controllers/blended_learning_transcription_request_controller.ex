defmodule DbserviceWeb.BlendedLearningTranscriptionRequestController do
  use DbserviceWeb, :controller

  alias Dbservice.BlendedLearning.TranscriptionRequests

  def show(conn, %{"request_key" => request_key}) do
    case TranscriptionRequests.get_transcription_request(request_key) do
      {:ok, request} ->
        json(conn, request)

      {:error, :transcription_request_not_found} ->
        error(
          conn,
          :not_found,
          "transcription_request_not_found",
          "Transcription Request not found"
        )
    end
  end

  def update_status(conn, %{"request_key" => request_key} = params) do
    case TranscriptionRequests.update_transcription_request_status(request_key, params) do
      {:ok, request} ->
        json(conn, request)

      {:error, :transcription_request_not_found} ->
        error(
          conn,
          :not_found,
          "transcription_request_not_found",
          "Transcription Request not found"
        )

      {:error, :invalid_request} ->
        error(
          conn,
          :unprocessable_entity,
          "invalid_request",
          "Status fields are missing or invalid"
        )

      {:error, :invalid_transition} ->
        error(conn, :conflict, "invalid_status_transition", "Status transition is invalid")

      {:error, :terminal_status_conflict} ->
        error(conn, :conflict, "terminal_status_conflict", "Transcription Request is terminal")

      {:error, :etl_run_conflict} ->
        error(conn, :conflict, "etl_run_conflict", "ETL run conflicts with this request")
    end
  end

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
