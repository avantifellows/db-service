defmodule Dbservice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Dbservice.DataImport.init_token_tracker()

    children = [
      # Start the Ecto repository
      Dbservice.Repo,
      # Start the Telemetry supervisor
      DbserviceWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Dbservice.PubSub},
      # Start the Endpoint (http/https)
      DbserviceWeb.Endpoint,
      # Start a worker by calling: Dbservice.Worker.start_link(arg)
      # {Dbservice.Worker, arg}
      {Oban, Application.fetch_env!(:dbservice, Oban)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
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
