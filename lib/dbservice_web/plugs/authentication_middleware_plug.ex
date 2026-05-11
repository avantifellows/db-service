defmodule DbserviceWeb.AuthenticationMiddleware do
  @moduledoc """
  This module provides a Plug middleware for handling API key-based authentication.

  The middleware checks the 'Authorization' header of incoming HTTP requests to ensure that
  it matches a predefined API key stored in the 'BEARER_TOKEN' environment variable.

  If the API key is valid, the request is allowed to proceed; otherwise, a '401 Unauthorized'
  response is sent, and further processing is halted.
  """
  import Plug.Conn
  import Dotenvy

  def init(_opts), do: %{}

  # Public endpoints exempt from bearer-token auth. The ALB target group
  # health check has no way to inject an auth header, so /api/health must
  # respond on plain GETs.
  @public_paths ["/api/health"]

  def call(conn, _opts) do
    source(["config/.env", System.get_env()])

    # Only enforce Bearer-token auth for the JSON API.
    # Browser routes (imports UI, swagger UI, live dashboard, etc.) should be protected
    # via their own dedicated auth mechanisms at the router level.
    cond do
      conn.request_path in @public_paths ->
        conn

      String.starts_with?(conn.request_path, "/api") ->
        api_key = get_req_header(conn, "authorization")

        if api_key == ["Bearer " <> env!("BEARER_TOKEN", :string!)] do
          conn
        else
          conn
          |> send_resp(401, "Not Authorized")
          |> halt()
        end

      true ->
        conn
    end
  end
end
