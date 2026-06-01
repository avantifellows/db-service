defmodule Dbservice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Dbservice.Utils.Util
  import Dotenvy

  @impl true
  def start(_type, _args) do
    source(["config/.env", System.get_env()])

    children = [
      # Start the Ecto repository
      Dbservice.Repo,
      # Start the Telemetry supervisor
      DbserviceWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Dbservice.PubSub},
      # Start the Endpoint (http/https)
      DbserviceWeb.Endpoint,
      # Start Oban
      {Oban, Application.fetch_env!(:dbservice, Oban)}
    ]

    # Only start Goth (Google Auth) if credentials are available
    # This allows tests to run without Google credentials
    children = children ++ goth_child_spec()

    opts = [strategy: :one_for_one, name: Dbservice.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp goth_child_spec do
    case blank_to_nil(env!("GOOGLE_CREDENTIALS_JSON", :string, nil)) do
      nil ->
        case blank_to_nil(env!("PATH_TO_CREDENTIALS", :string, nil)) do
          nil -> handle_missing_credentials()
          json_path -> load_credentials_from_file(json_path)
        end

      json_string ->
        build_goth_spec(json_string)
    end
  end

  # Env vars injected as empty strings (e.g. a blank ECS task override) should
  # be treated as "not set" rather than a present-but-empty path/JSON.
  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp handle_missing_credentials do
    if Application.get_env(:dbservice, :environment) == :test do
      []
    else
      raise "GOOGLE_CREDENTIALS_JSON or PATH_TO_CREDENTIALS environment variable is required"
    end
  end

  defp load_credentials_from_file(json_path) do
    case File.read(json_path) do
      {:ok, content} -> build_goth_spec(content)
      {:error, reason} -> handle_credentials_error(reason)
    end
  end

  defp build_goth_spec(content) do
    credentials = Jason.decode!(content) |> Util.process_credentials()

    [
      {Goth,
       name: Dbservice.Goth,
       source:
         {:service_account, credentials,
          scopes: [
            "https://www.googleapis.com/auth/spreadsheets",
            "https://www.googleapis.com/auth/drive.readonly"
          ]}}
    ]
  rescue
    error ->
      # Don't let malformed Google credentials crash the whole service — the
      # REST API and health check must stay up even if Sheets auth is broken.
      require Logger
      Logger.error("Goth init failed, starting without Google auth: #{inspect(error)}")
      []
  end

  defp handle_credentials_error(reason) do
    if Application.get_env(:dbservice, :environment) == :test do
      []
    else
      raise "Failed to read Google service account JSON: #{inspect(reason)}"
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DbserviceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
