defmodule DbserviceWeb.HolisticMentorshipProfilePreflightController do
  use DbserviceWeb, :controller

  alias Dbservice.HolisticMentorship

  def create(conn, %{"records" => records})
      when is_list(records) and records != [] and length(records) <= 100 do
    json(conn, %{results: HolisticMentorship.profile_preflight(records)})
  end

  def create(conn, %{"records" => records}) when is_list(records) and length(records) > 100 do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "batch_too_large",
        message: "Profile Preflight accepts at most 100 records"
      }
    })
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "invalid_request",
        message: "Profile Preflight requires 1 through 100 records"
      }
    })
  end
end
