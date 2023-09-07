defmodule DbserviceWeb.AuthenticationMiddleware do
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
