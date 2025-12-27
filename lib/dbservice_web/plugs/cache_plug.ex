defmodule DbserviceWeb.CachePlug do
  @moduledoc """
  A plug that caches GET responses using Cachex for a configurable TTL (default: 3 minutes).

  - Caches only `GET` requests.
  - Emits telemetry events for cache hits/misses.
  - Adds `x-cache` header (`HIT` or `MISS`).
  """

  import Plug.Conn

  @default_ttl :timer.minutes(3)

  def init(opts), do: opts

  def call(%Plug.Conn{method: "GET"} = conn, opts) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    cache_key = build_cache_key(conn)

    case Cachex.get(:dbservice_cache, cache_key) do
      {:ok, nil} ->
        handle_cache_miss(conn, cache_key, ttl)

      {:ok, cached_body} ->
        handle_cache_hit(conn, cache_key, cached_body)
    end
  end

  def call(conn, _opts), do: conn

  defp handle_cache_hit(conn, cache_key, cached_body) do
    :telemetry.execute(
      [:dbservice, :cache, :hit],
      %{count: 1},
      %{key: cache_key, path: conn.request_path}
    )

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("x-cache", "HIT")
    |> send_resp(200, cached_body)
    |> halt()
  end

  defp handle_cache_miss(conn, cache_key, ttl) do
    register_before_send(conn, fn conn ->
      if conn.status == 200 and conn.resp_body != "" do
        Cachex.put(:dbservice_cache, cache_key, conn.resp_body, ttl: ttl)

        :telemetry.execute(
          [:dbservice, :cache, :miss],
          %{count: 1},
          %{key: cache_key, path: conn.request_path}
        )
      end

      put_resp_header(conn, "x-cache", "MISS")
    end)
  end

  defp build_cache_key(conn) do
    "http:#{conn.request_path}?#{conn.query_string}"
  end
end
