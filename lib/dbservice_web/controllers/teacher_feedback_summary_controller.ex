defmodule DbserviceWeb.TeacherFeedbackSummaryController do
  use DbserviceWeb, :controller

  alias Dbservice.TeacherFeedbackSummaries

  # GET /api/teacher-feedback-summary?session_pks=1,2,3
  def index(conn, %{"session_pks" => session_pks}) when is_binary(session_pks) do
    case parse_ids(session_pks) do
      {:ok, ids} -> json(conn, TeacherFeedbackSummaries.list_by_session_pks(ids))
      :error -> bad_request(conn, "session_pks must be comma-separated integers")
    end
  end

  def index(conn, _params), do: bad_request(conn, "session_pks is required")

  # PUT /api/teacher-feedback-summary/:session_pk
  # {summary, summary_prompt_version, summary_fingerprint}
  def update(conn, %{"session_pk" => session_pk} = params) do
    with {pk, ""} <- Integer.parse(session_pk),
         {:ok, count} when count > 0 <- TeacherFeedbackSummaries.put_summary(pk, params) do
      json(conn, %{updated: count})
    else
      {:ok, 0} ->
        conn |> put_status(:not_found) |> json(%{error: "No feedback form for this session"})

      {:error, reason} ->
        bad_request(conn, reason)

      _ ->
        bad_request(conn, "session_pk must be an integer")
    end
  end

  defp parse_ids(text) do
    text
    |> String.split(",", trim: true)
    |> Enum.reduce_while({:ok, []}, fn part, {:ok, acc} ->
      case Integer.parse(String.trim(part)) do
        {id, ""} -> {:cont, {:ok, [id | acc]}}
        _ -> {:halt, :error}
      end
    end)
  end

  defp bad_request(conn, message) do
    conn |> put_status(:bad_request) |> json(%{error: message})
  end
end
