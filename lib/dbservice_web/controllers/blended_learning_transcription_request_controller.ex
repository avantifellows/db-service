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

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
