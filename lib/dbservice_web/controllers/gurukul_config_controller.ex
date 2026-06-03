defmodule DbserviceWeb.GurukulConfigController do
  use DbserviceWeb, :controller

  alias Dbservice.Services.GurukulConfigService

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  swagger_path :show do
    get("/api/gurukul-config")

    description(
      "Resolves the merged Gurukul UI configuration using the fallback chain " <>
        "batch -> program -> defaultgroup. Provide exactly one of user_id, batch_id " <>
        "or program_id. For user_id the oldest current batch/program is used."
    )

    parameters do
      user_id(:query, :integer, "Resolve config for this user", required: false)
      batch_id(:query, :integer, "Resolve config for this batch directly", required: false)
      program_id(:query, :integer, "Resolve config for this program directly", required: false)
    end

    response(200, "Success")
    response(400, "Bad Request")
  end

  def show(conn, params) do
    with {:ok, scope, id} <- pick_scope(params),
         {:ok, int_id} <- parse_int(id) do
      {config, resolved_from} = resolve(scope, int_id)

      conn
      |> put_status(:ok)
      |> render(:show, config: config, resolved_from: resolved_from)
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> render(:error, error: message)
    end
  end

  defp resolve(:user, id), do: GurukulConfigService.resolve_for_user(id)
  defp resolve(:batch, id), do: GurukulConfigService.resolve_for_batch(id)
  defp resolve(:program, id), do: GurukulConfigService.resolve_for_program(id)

  defp pick_scope(params) do
    cond do
      present?(params["user_id"]) -> {:ok, :user, params["user_id"]}
      present?(params["batch_id"]) -> {:ok, :batch, params["batch_id"]}
      present?(params["program_id"]) -> {:ok, :program, params["program_id"]}
      true -> {:error, "One of user_id, batch_id or program_id is required"}
    end
  end

  defp parse_int(value) do
    case Integer.parse(to_string(value)) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "Identifier must be an integer"}
    end
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_), do: true
end
