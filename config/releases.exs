import Config

http_port = System.get_env("HTTP_PORT") || 4000

config :dbservice, DbserviceWeb.Endpoint,
  server: true,
  http: [port: http_port], # Needed for Phoenix 1.2 and 1.4. Doesn't hurt for 1.3.
  url: [host: System.get_env("APP_NAME") <> ".gigalixirapp.com", port: 443]
