defmodule DbserviceWeb.HolisticMentorshipRegenerationRequestController do
  use DbserviceWeb, :controller

  alias Dbservice.HolisticMentorship

  def show(conn, %{"request_key" => request_key}) do
    case HolisticMentorship.get_regeneration_request(request_key) do
      {:ok, request} ->
        json(conn, request)

      {:error, :regeneration_request_not_found} ->
        error(
          conn,
          :not_found,
          "regeneration_request_not_found",
          "Regeneration Request not found"
        )

      {:error, reason} ->
        error(conn, :unprocessable_entity, Atom.to_string(reason), "Student is not eligible")
    end
  end

  def update_status(conn, %{"request_key" => request_key} = params) do
    case HolisticMentorship.update_regeneration_request_status(request_key, params) do
      {:ok, request} ->
        json(conn, request)

      {:error, :regeneration_request_not_found} ->
        error(
          conn,
          :not_found,
          "regeneration_request_not_found",
          "Regeneration Request not found"
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
        error(conn, :conflict, "terminal_status_conflict", "Regeneration Request is terminal")

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
