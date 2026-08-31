defmodule DbserviceWeb.HolisticMentorshipPromptConfigurationController do
  use DbserviceWeb, :controller

  alias Dbservice.HolisticMentorship

  def create(conn, params) do
    case HolisticMentorship.register_prompt_configuration(params) do
      {:ok, configuration} ->
        json(conn, configuration)

      {:error, :template_hash_mismatch} ->
        error(
          conn,
          :unprocessable_entity,
          "template_hash_mismatch",
          "Template hash does not match template text"
        )

      {:error, :prompt_version_conflict} ->
        error(
          conn,
          :conflict,
          "prompt_version_conflict",
          "Prompt Version already exists with different content"
        )

      {:error, :invalid_request} ->
        error(
          conn,
          :unprocessable_entity,
          "invalid_request",
          "Required prompt configuration fields are missing or invalid"
        )
    end
  end

  def activate(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {configuration_id, ""} -> activate_configuration(conn, configuration_id)
      _ -> prompt_configuration_not_found(conn)
    end
  end

  defp activate_configuration(conn, id) do
    case HolisticMentorship.activate_prompt_configuration(id) do
      {:ok, configuration} ->
        json(conn, configuration)

      {:error, :prompt_configuration_not_found} ->
        prompt_configuration_not_found(conn)
    end
  end

  defp prompt_configuration_not_found(conn) do
    error(
      conn,
      :not_found,
      "prompt_configuration_not_found",
      "Prompt Configuration not found"
    )
  end

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
