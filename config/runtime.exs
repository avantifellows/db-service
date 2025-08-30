import Config
import Dotenvy

source(["config/.env", "config/.env.#{config_env()}"])

if config_env() == :prod do
  # Database configuration with optimized pool settings
  config :dbservice, Dbservice.Repo,
    url: env!("DATABASE_URL", :string!),
    pool_size: env!("POOL_SIZE", :integer) || 50,
    ssl: [
      verify: :verify_none
    ],
    queue_target: env!("QUEUE_TARGET", :integer) || 10000,
    queue_interval: env!("QUEUE_INTERVAL", :integer) || 5000,
    timeout: env!("DB_TIMEOUT", :integer) || 60000

  secret_key_base = env!("SECRET_KEY_BASE", :string!)
  port = env!("PORT", :integer) || 4000
  host = env!("PHX_HOST", :string!)

  # Optimized endpoint configuration
  config :dbservice, DbserviceWeb.Endpoint,
    load_from_system_env: false,
    url: [host: host, port: 443],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port,
      # HTTP server optimizations
      protocol_options: [
        max_keepalive: env!("MAX_KEEPALIVE", :integer) || 2000,
        timeout: env!("HTTP_TIMEOUT", :integer) || 60000
      ],
      # Cowboy server optimizations
      transport_options: [
        max_connections: env!("MAX_CONNECTIONS", :integer) || 20000,
        num_acceptors: env!("NUM_ACCEPTORS", :integer) || 200
      ]
    ],
    secret_key_base: secret_key_base,
    debug_errors: true,
    check_origin: false
end
