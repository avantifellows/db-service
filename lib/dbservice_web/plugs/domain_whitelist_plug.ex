defmodule DbserviceWeb.DomainWhitelistPlug do
  @moduledoc """
  Only allow requests from the list of domains specified. Assumes the request domain is present in the `host`
  attribute on the passed in plug.
  If the request doamin is not whitelisted, the specified response code and body
  will be added to the Plug.Conn and it will be halted.
  If the request domain is on the whitelist, the plug chain will continue
  """
  import Plug.Conn
  import Dotenvy

  def init(options) do
    options
  end

  def call(conn, _options) do
    if allowed_domains?(conn) do
      conn
    else
      conn
      |> send_resp(403, "Not Authorized")
      |> halt()
    end
  end

  defp allowed_domains?(conn) do
    source(["config/.env", "config/.env"])

    whitelisted_domains = env!("WHITELISTED_DOMAINS", :string!)

    allowed_domains =
      if is_nil(whitelisted_domains),
        do: ["localhost"],
        else: String.split(whitelisted_domains, ",")

    Enum.member?(allowed_domains, conn.host)
  end
end
