defmodule Dbservice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Dbservice.Utils.Util
  import Dotenvy

  @impl true
  def start(_type, _args) do
    source(["config/.env"])

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
    case env!("PATH_TO_CREDENTIALS", :string, nil) do
      nil ->
        if Application.get_env(:dbservice, :environment) != :test do
          raise "PATH_TO_CREDENTIALS environment variable is required"
        end

        []

      json_path ->
        case File.read(json_path) do
          {:ok, content} ->
            credentials = Jason.decode!(content) |> Util.process_credentials()

            [
              {Goth,
               name: Dbservice.Goth,
               source:
                 {:service_account, credentials,
                  [
                    scopes: [
                      "https://www.googleapis.com/auth/spreadsheets",
                      "https://www.googleapis.com/auth/drive.readonly"
                    ]
                  ]}}
            ]

          {:error, reason} ->
            if Application.get_env(:dbservice, :environment) == :test do
              []
            else
              raise "Failed to read Google service account JSON: #{inspect(reason)}"
            end
        end
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
