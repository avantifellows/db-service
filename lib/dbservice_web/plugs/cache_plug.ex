defmodule DbserviceWeb.CachePlug do
  import Plug.Conn

  @default_ttl :timer.minutes(3)

  def init(opts), do: opts

  def call(conn, opts) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    # Only cache GET requests
    if conn.method == "GET" do
      cache_key = build_cache_key(conn)

      case Cachex.get(:dbservice_cache, cache_key) do
        {:ok, nil} ->
          register_before_send(conn, fn conn ->
            if conn.status == 200 and conn.resp_body != "" do
              Cachex.put(:dbservice_cache, cache_key, conn.resp_body, ttl: ttl)

              # Emit telemetry event for cache miss
              :telemetry.execute(
                [:dbservice, :cache, :miss],
                %{count: 1},
                %{key: cache_key, path: conn.request_path}
              )
            end

            put_resp_header(conn, "x-cache", "MISS")
          end)

        {:ok, cached_body} ->
          # Cache hit - return immediately
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
    else
      conn
    end
  end

  # Build deterministic cache key based on request path + query params
  defp build_cache_key(conn) do
    "http:#{conn.request_path}?#{conn.query_string}"
  end
end
