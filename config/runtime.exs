import Config
import Dotenvy

source(["config/.env", "config/.env.#{config_env()}", System.get_env()])

if config_env() == :prod do
  config :dbservice, Dbservice.Repo,
    url: env!("DATABASE_URL", :string!),
    ssl: true,
    # Postgrex 0.18+ made `ssl: true` verify the server cert against the OS CA
    # store by default. The RDS cert chains to the Amazon RDS root CA, which
    # isn't in the default bundle, so verification fails with "Unknown CA" and
    # migrations/connections can't be established. We keep the connection
    # encrypted but skip CA verification to restore the pre-0.18 behaviour.
    ssl_opts: [verify: :verify_none],
    pool_size: env!("POOL_SIZE", :integer, 10)

  secret_key_base = env!("SECRET_KEY_BASE", :string!)
  port = env!("PORT", :integer, 4000)
  host = env!("PHX_HOST", :string!)

  config :dbservice, DbserviceWeb.Endpoint,
    load_from_system_env: false,
    url: [host: host, port: 443],
    http: [
      # Bind on IPv4 all-interfaces. The ECS/Fargate ALB target group connects
      # to the task's IPv4 ENI address, so an IPv6-only bind ({0,0,0,0,0,0,0,0})
      # makes the ALB health check time out even though the app is up.
      ip: {0, 0, 0, 0},
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

# Google SSO for the /imports admin UI — configured in every environment so
# local development uses the same code path as production.
#
# `allowed_domain` is enforced server-side on the profile Google returns, so a
# personal Gmail account can't reach the imports UI even if it completes the
# OAuth flow.
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: env!("GOOGLE_OAUTH_CLIENT_ID", :string, nil),
  client_secret: env!("GOOGLE_OAUTH_CLIENT_SECRET", :string, nil)

config :dbservice, :imports_auth,
  allowed_domain: env!("IMPORTS_ALLOWED_DOMAIN", :string, "avantifellows.org"),
  # Escape hatch for local development and tests only. This is additionally
  # gated on the compile-time Mix environment in DbserviceWeb.UserAuth, so
  # setting it on a production host has no effect.
  bypass: env!("IMPORTS_AUTH_BYPASS", :boolean, false),
  bypass_email: env!("IMPORTS_AUTH_BYPASS_EMAIL", :string, "dev@localhost")
