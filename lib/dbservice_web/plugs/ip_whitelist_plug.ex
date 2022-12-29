defmodule DbserviceWeb.IpWhitelistPlug do
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
    allowed_ips = ['127.0.0.1', '35.190.11.178']
    ip = :inet_parse.ntoa(conn.remote_ip)
    Enum.member?(allowed_ips, ip)
  end
end
