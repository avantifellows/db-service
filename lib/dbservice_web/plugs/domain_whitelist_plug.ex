defmodule DbserviceWeb.DomainWhitelistPlug do
  @moduledoc """
    Only allow requests from the list of IP addresses specified. Assumes the request ip is present in the `remote_ip`
    attribute on the passed in plug.
    If the request IP is not whitelisted, the specified response code and body
      will be added to the Plug.Conn and it will be halted.
    If the request IP is on the whitelist, the plug chain will continue
  """
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _options) do
    if allowed_domains?(conn) do
      conn
    else
      send_resp(conn, 403, "Not Authorized")
    end
  end

  defp allowed_domains?(conn) do
    allowed_domains = ["localhost"]
    domain = conn.host
    Enum.member?(allowed_domains, domain)
  end
end
