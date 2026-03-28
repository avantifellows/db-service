import Config

# Mark this as test environment for conditional logic
config :dbservice, environment: :test

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :dbservice, Dbservice.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dbservice_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dbservice, DbserviceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "26b3HUmivehfPuHgsIsvAgOtQYEUDngI8yHnJ5fJ91RP3MT3xsTqp6aggFa0gRC+",
  server: false

# In test we don't send emails.
config :dbservice, Dbservice.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable Oban queues and plugins during tests to avoid DB usage
config :dbservice, Oban, testing: :manual, queues: false, plugins: false
