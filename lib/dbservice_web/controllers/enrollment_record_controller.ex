defmodule DbserviceWeb.EnrollmentRecordController do
  use DbserviceWeb, :controller

  alias Dbservice.Schools
  alias Dbservice.Schools.EnrollmentRecord

  action_fallback DbserviceWeb.FallbackController

  def index(conn, _params) do
    enrollment_record = Schools.list_enrollment_record()
    render(conn, "index.json", enrollment_record: enrollment_record)
  end

  def create(conn, params) do
    with {:ok, %EnrollmentRecord{} = enrollment_record} <-
           Schools.create_enrollment_record(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.enrollment_record_path(conn, :show, enrollment_record)
      )
      |> render("show.json", enrollment_record: enrollment_record)
    end
  end

  def show(conn, %{"id" => id}) do
    enrollment_record = Schools.get_enrollment_record!(id)
    render(conn, "show.json", enrollment_record: enrollment_record)
  end

  def update(conn, params) do
    enrollment_record = Schools.get_enrollment_record!(params["id"])

    with {:ok, %EnrollmentRecord{} = enrollment_record} <-
           Schools.update_enrollment_record(enrollment_record, params) do
      render(conn, "show.json", enrollment_record: enrollment_record)
    end
  end

  def delete(conn, %{"id" => id}) do
    enrollment_record = Schools.get_enrollment_record!(id)

    with {:ok, %EnrollmentRecord{}} <- Schools.delete_enrollment_record(enrollment_record) do
      send_resp(conn, :no_content, "")
    end
  end
end
