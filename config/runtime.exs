import Config
import Dotenvy

source(["config/.env", "config/.env.#{config_env()}", System.get_env()])

if config_env() == :prod do
  config :dbservice, Dbservice.Repo,
    url: env!("DATABASE_URL", :string!),
    ssl: true,
    pool_size: env!("POOL_SIZE", :integer) || 10

  secret_key_base = env!("SECRET_KEY_BASE", :string!)
  port = env!("PORT", :integer) || 4000
  host = env!("PHX_HOST", :string!)

  config :dbservice, DbserviceWeb.Endpoint,
    load_from_system_env: false,
    url: [host: host, port: 443],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    debug_errors: false,
    check_origin: ["//#{host}"]

  # `mix phx.server` (the EC2 deploy) turns serving on by itself, so leave
  # :server unset on that path. OTP releases (ECS) don't, so flip it on when
  # PHX_SERVER is set — rel/env.sh.eex exports it for `bin/dbservice start`.
  # Setting `server: false` explicitly (the previous behaviour) overrode
  # mix phx.server and stopped the EC2 deploy from ever listening.
  if System.get_env("PHX_SERVER") in ~w(1 true) do
    config :dbservice, DbserviceWeb.Endpoint, server: true
  end
end
