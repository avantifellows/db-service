defmodule DbserviceWeb.AuthenticationMiddleware do
  @moduledoc """
  Plug for API Bearer-token authentication.

  Only requests whose path starts with `"/api"` are checked. The expected header
  value is `Bearer <BEARER_TOKEN>` as configured once in `config/runtime.exs`
  (`:api_expected_authorization`). Browser routes (imports UI, Swagger UI, Live
  Dashboard, etc.) are left to other auth at the router / pipeline level.

  The expected header is read in `call/2`, not in `init/1`. In production,
  Phoenix uses `plug_init_mode: :compile`, so `init/1` runs at **compile** time
  when `:dbservice` is not yet loaded and `Application.fetch_env!/2` would raise.

  Unauthorized API requests receive `401` and the pipeline stops.
  """
  import Plug.Conn

  @init_tag :api_expected_authorization_from_config

  def init(_opts), do: @init_tag

  def call(conn, @init_tag) do
    expected = Application.fetch_env!(:dbservice, :api_expected_authorization)

    if String.starts_with?(conn.request_path, "/api") do
      api_key = get_req_header(conn, "authorization")

      if api_key == [expected] do
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
