defmodule DbserviceWeb.HealthController do
  use DbserviceWeb, :controller

  alias Dbservice.Repo

  # Liveness probe used by the ALB target group. Intentionally does NOT touch
  # the database: under load the DB pool can be momentarily exhausted by slow
  # queries, and if liveness depended on a free connection the busy-but-alive
  # task would fail its health check and get recycled — removing capacity right
  # when it's needed and (with a small task count) dropping the service to zero
  # healthy targets. Keep this cheap; use /api/health/ready for DB connectivity.
  def index(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{status: "ok"})
  end

  # Readiness probe — verifies DB connectivity. Use this for deep monitoring
  # (dashboards/alarms), NOT as the ALB liveness check.
  def ready(conn, _params) do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok"})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", reason: inspect(reason)})
    end
  end
end
