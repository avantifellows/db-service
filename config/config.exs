# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config
import Dotenv

Dotenv.load()

config :dbservice,
  ecto_repos: [Dbservice.Repo]

# Configures the endpoint
config :dbservice, DbserviceWeb.Endpoint,
  load_from_system_env: false,
  url: [host: "localhost"],
  render_errors: [view: DbserviceWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Dbservice.PubSub,
  live_view: [signing_salt: "KptGRhXD"]

# Configures the mailer
#
# By default, it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production, it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dbservice, Dbservice.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :dbservice, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      # phoenix routes will be converted to swagger paths
      router: DbserviceWeb.Router,
      # (optional) endpoint config used to set host, port, and https schemes.
      endpoint: DbserviceWeb.Endpoint
    ]
  }

# Use Jason for JSON parsing in Phoenix
config :phoenix_swagger, :json_library, Jason

# Increase timeout time
config :dbservice, Dbservice.Repo,
  timeout: 120_000,
  queue_target: 15_000,
  queue_interval: 100_000

# Import environment-specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :dbservice, env: Mix.env()
