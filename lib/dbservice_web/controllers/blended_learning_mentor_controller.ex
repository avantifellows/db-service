defmodule DbserviceWeb.BlendedLearningMentorController do
  use DbserviceWeb, :controller
  use PhoenixSwagger

  alias Dbservice.BlendedLearning

  swagger_path :show do
    get("/api/blended-learning/mentor")

    description(
      "The Blended Learning mentor currently assigned to a student, by the " <>
        "student's user id. Returns the mentor's name and user id only — no " <>
        "phone, WhatsApp number or email. Optionally narrowed to one academic " <>
        "year; without it the most recently started running mapping is " <>
        "returned. 404 when the student has no running mapping, which is the " <>
        "ordinary case outside Blended Learning."
    )

    parameters do
      user_id(:query, :integer, "The student's user id", required: true)

      academic_year(:query, :string, "Limit to this academic year, e.g. 2026-2027",
        required: false
      )
    end

    response(200, "Success")
    response(400, "Bad Request")
    response(404, "Not Found")
  end

  def show(conn, params) do
    with {:ok, user_id} <- fetch_user_id(params),
         academic_year = presence(params["academic_year"]),
         mapping when not is_nil(mapping) <-
           BlendedLearning.active_mentor_for_user(user_id, academic_year) do
      json(conn, mapping)
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{code: "invalid_request", message: message}})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: %{
            code: "mentor_mapping_not_found",
            message: "Student has no running mentor mapping"
          }
        })
    end
  end

  defp fetch_user_id(params) do
    case presence(params["user_id"]) do
      nil ->
        {:error, "user_id is required"}

      value ->
        case Integer.parse(value) do
          {user_id, ""} -> {:ok, user_id}
          _ -> {:error, "user_id must be an integer"}
        end
    end
  end

  defp presence(nil), do: nil

  defp presence(value) do
    case String.trim(to_string(value)) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
