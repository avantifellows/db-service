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

  def call(conn, _opts) do
    source(["config/.env", "config/.env"])

    api_key = get_req_header(conn, "authorization")

    if api_key == ["Bearer " <> env!("BEARER_TOKEN", :string!)] do
      conn
    else
      conn
      |> send_resp(401, "Not Authorized")
      |> halt()
    end
  end
end
