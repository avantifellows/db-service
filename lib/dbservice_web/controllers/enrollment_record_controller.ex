defmodule DbserviceWeb.EnrollmentRecordController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Schools
  alias Dbservice.Schools.EnrollmentRecord

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.EnrollmentRecord, as: SwaggerSchemaEnrollmentRecord

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaEnrollmentRecord.enrollment_record(),
      SwaggerSchemaEnrollmentRecord.enrollment_records()
    )
  end

  swagger_path :index do
    get("/api/enrollment-record")
    response(200, "OK", Schema.ref(:EnrollmentRecords))
  end

  def index(conn, params) do
    param = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)

    enrollment_record =
      Enum.reduce(param, EnrollmentRecord, fn
        {key, value}, query ->
          from u in query, or_where: field(u, ^key) == ^value

        _, query ->
          query
      end)
      |> Repo.all()

    render(conn, "index.json", enrollment_record: enrollment_record)
  end

  swagger_path :create do
    post("/api/enrollment-record")

    parameters do
      body(:body, Schema.ref(:EnrollmentRecord), "Enrollment record to create", required: true)
    end

    response(201, "Created", Schema.ref(:EnrollmentRecord))
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

  swagger_path :show do
    get("/api/enrollment-record/{enrollmentRecordId}")

    parameters do
      enrollmentRecordId(:path, :integer, "The id of the enrollment record", required: true)
    end

    response(200, "OK", Schema.ref(:EnrollmentRecord))
  end

  def show(conn, %{"id" => id}) do
    enrollment_record = Schools.get_enrollment_record!(id)
    render(conn, "show.json", enrollment_record: enrollment_record)
  end

  swagger_path :update do
    patch("/api/enrollment-record/{enrollmentRecordId}")

    parameters do
      enrollmentRecordId(:path, :integer, "The id of the enrollment record", required: true)
      body(:body, Schema.ref(:EnrollmentRecord), "Enrollment record to create", required: true)
    end

    response(200, "Updated", Schema.ref(:EnrollmentRecord))
  end

  def update(conn, params) do
    enrollment_record = Schools.get_enrollment_record!(params["id"])

    with {:ok, %EnrollmentRecord{} = enrollment_record} <-
           Schools.update_enrollment_record(enrollment_record, params) do
      render(conn, "show.json", enrollment_record: enrollment_record)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/enrollment-record/{enrollmentRecordId}")

    parameters do
      enrollmentRecordId(:path, :integer, "The id of the enrollment record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    enrollment_record = Schools.get_enrollment_record!(id)

    with {:ok, %EnrollmentRecord{}} <- Schools.delete_enrollment_record(enrollment_record) do
      send_resp(conn, :no_content, "")
    end
  end
end
