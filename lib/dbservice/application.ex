defmodule Dbservice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Dbservice.Utils.Util
  import Dotenvy

  @impl true
  def start(_type, _args) do
    Dbservice.DataImport.init_token_tracker()
    source(["config/.env"])

    # Read and decode the JSON file
    json_path = env!("PATH_TO_CREDENTIALS", :string!)

    credentials =
      case File.read(json_path) do
        {:ok, content} ->
          Jason.decode!(content)

        {:error, reason} ->
          raise "Failed to read Google service account JSON: #{inspect(reason)}"
      end

    # Ensure the private key is correctly formatted
    credentials = Util.process_credentials(credentials)

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
      {Oban, Application.fetch_env!(:dbservice, Oban)},
      # Start Goth with additional configuration
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

    opts = [strategy: :one_for_one, name: Dbservice.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DbserviceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
