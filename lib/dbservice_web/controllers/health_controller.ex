defmodule DbserviceWeb.HealthController do
  use DbserviceWeb, :controller

  alias Dbservice.Repo

  def index(conn, _params) do
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
