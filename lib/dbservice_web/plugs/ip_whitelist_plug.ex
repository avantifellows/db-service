defmodule DbserviceWeb.IpWhitelistPlug do
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
    if allowed_ip?(conn) do
      conn
    else
      send_resp(conn, 403, "Not Authorized")
    end
  end

  defp allowed_ip?(conn) do
    allowed_ips = ['128.0.0.1', "127.0.0.1", "35.190.11.178", '35.190.11.178']
    IO.inspect(conn)
    IO.inspect(conn.remote_ip)
    ip = :inet_parse.ntoa(conn.remote_ip)
    Enum.member?(allowed_ips, ip)
  end
end
