defmodule DbserviceWeb.HolisticMentorshipProfileGenerationStatusController do
  use DbserviceWeb, :controller

  alias Dbservice.HolisticMentorship

  def create(conn, params) do
    case HolisticMentorship.record_profile_generation_status(params) do
      {:ok, status} ->
        json(conn, status)

      {:error, :invalid_request} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            code: "invalid_request",
            message: "Profile generation status fields are missing or invalid"
          }
        })

      {:error, :invalid_transition} ->
        error(
          conn,
          :conflict,
          "invalid_status_transition",
          "Profile generation status transition is invalid"
        )

      {:error, :terminal_status_conflict} ->
        error(
          conn,
          :conflict,
          "terminal_status_conflict",
          "Profile generation status is terminal"
        )
    end
  end

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
