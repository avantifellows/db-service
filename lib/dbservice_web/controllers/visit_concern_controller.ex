defmodule DbserviceWeb.VisitConcernController do
  use DbserviceWeb, :controller

  require Dbservice.VisitConcerns
  alias Dbservice.VisitConcerns

  # GET /api/visit-concerns/pending-visits?prompt_version=v1
  #   &limit=50&after_visit_date=2026-10-10&after_id=12&visit_ids=1,2&force=false
  def pending_visits(conn, params) do
    case parse_pending_params(params) do
      {:ok, opts} -> json(conn, VisitConcerns.list_pending_visits(opts))
      {:error, message} -> bad_request(conn, message)
    end
  end

  # PUT /api/visit-concerns/visit-summary/:visit_id
  #   {fingerprint, prompt_version, points: [{existing_id, kind, snippet} | {new: {kind, text}, snippet}]}
  def update_summary(conn, %{"visit_id" => visit_id} = params) do
    with {:ok, id} <- parse_id(visit_id),
         {:ok, records} <- VisitConcerns.put_visit_summary(id, params) do
      json(conn, %{records: records})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Visit not found or not completed"})

      {:error, message} ->
        bad_request(conn, message)

      _ ->
        bad_request(conn, "visit_id must be a positive integer")
    end
  end

  defp parse_pending_params(params) do
    with {:ok, prompt_version} <- VisitConcerns.fetch_prompt_version(params),
         {:ok, limit} <- parse_limit(params),
         {:ok, cursor} <- parse_cursor(params),
         {:ok, visit_ids} <- parse_visit_ids(params),
         {:ok, force} <- parse_force(params) do
      {:ok,
       %{
         prompt_version: prompt_version,
         limit: limit,
         cursor: cursor,
         visit_ids: visit_ids,
         force: force
       }}
    end
  end

  defp parse_limit(params) do
    with value when is_binary(value) <- Map.get(params, "limit", "50"),
         {limit, ""} when limit in 1..200 <- Integer.parse(value) do
      {:ok, limit}
    else
      _ -> {:error, "limit must be an integer from 1 to 200"}
    end
  end

  defp parse_cursor(%{"after_visit_date" => date, "after_id" => id})
       when is_binary(date) and is_binary(id) do
    with {:ok, visit_date} <- Date.from_iso8601(date),
         {:ok, visit_id} <- parse_id(id) do
      {:ok, {visit_date, visit_id}}
    else
      _ -> {:error, "after_visit_date must be YYYY-MM-DD and after_id a positive integer"}
    end
  end

  defp parse_cursor(params) do
    if Map.has_key?(params, "after_visit_date") or Map.has_key?(params, "after_id"),
      do: {:error, "after_visit_date and after_id must be given together"},
      else: {:ok, nil}
  end

  defp parse_visit_ids(params) do
    case Map.get(params, "visit_ids") do
      nil ->
        {:ok, nil}

      text when is_binary(text) ->
        case parse_ids(text) do
          {:ok, ids} when length(ids) <= 200 -> {:ok, ids}
          {:ok, _ids} -> {:error, "visit_ids must list at most 200 ids"}
          :error -> {:error, "visit_ids must be comma-separated positive integers"}
        end

      _ ->
        {:error, "visit_ids must be comma-separated positive integers"}
    end
  end

  defp parse_ids(text) do
    text
    |> String.split(",", trim: true)
    |> Enum.reduce_while({:ok, []}, fn part, {:ok, acc} ->
      case parse_id(String.trim(part)) do
        {:ok, id} -> {:cont, {:ok, [id | acc]}}
        :error -> {:halt, :error}
      end
    end)
  end

  # A decimal id that fits a Postgres bigint; larger values would make Postgrex
  # raise (a 500) instead of a 400.
  defp parse_id(text) do
    case Integer.parse(text) do
      {id, ""} when VisitConcerns.is_id(id) -> {:ok, id}
      _ -> :error
    end
  end

  defp parse_force(params) do
    case Map.get(params, "force", "false") do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, "force must be true or false"}
    end
  end

  defp bad_request(conn, message) do
    conn |> put_status(:bad_request) |> json(%{error: message})
  end
end
