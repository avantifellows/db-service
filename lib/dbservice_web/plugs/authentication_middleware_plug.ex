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

    referer =
      get_req_header(conn, "referer")
      |> List.first()
      |> to_string()

    request_path = conn.request_path

    api_key = get_req_header(conn, "authorization")

    if api_key == ["Bearer " <> env!("BEARER_TOKEN", :string!)] ||
         root_path?(request_path) ||
         contains_swagger_request?(referer, request_path) ||
         contains_phoneix_livedashboard?(referer, request_path) ||
         contains_imports_path?(request_path) do
      conn
    else
      conn
      |> send_resp(401, "Not Authorized")
      |> halt()
    end
  end

  defp root_path?(path), do: path == "/"

  defp contains_swagger_request?(referer, request_path) do
    String.contains?(referer, "swagger") || String.contains?(request_path, "swagger")
  end

  defp contains_phoneix_livedashboard?(referer, request_path) do
    String.contains?(referer, "dashboard") || String.contains?(request_path, "dashboard")
  end

  defp contains_imports_path?(request_path) do
    String.contains?(request_path, "/imports") || String.contains?(request_path, "/templates")
  end
end
