defmodule DbserviceWeb.AuthenticationMiddleware do
  @moduledoc """
  Plug for API Bearer-token authentication.

  Only requests whose path starts with `"/api"` are checked. The expected header
  value is `Bearer <BEARER_TOKEN>` as configured once in `config/runtime.exs`
  (`:api_expected_authorization`). Browser routes (imports UI, Swagger UI, Live
  Dashboard, etc.) are left to other auth at the router / pipeline level.

  Unauthorized API requests receive `401` and the pipeline stops.
  """
  import Plug.Conn

  def init(_opts), do: Application.fetch_env!(:dbservice, :api_expected_authorization)

  def call(conn, expected_authorization_header) when is_binary(expected_authorization_header) do
    if String.starts_with?(conn.request_path, "/api") do
      api_key = get_req_header(conn, "authorization")

      if api_key == [expected_authorization_header] do
        conn
      else
        conn
        |> send_resp(401, "Not Authorized")
        |> halt()
      end
    else
      conn
    end
  end
end
