defmodule DbserviceWeb.EnrollmentRecordController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.EnrollmentRecords

  action_fallback(DbserviceWeb.FallbackController)

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

    parameters do
      params(:query, :string, "The academic year of the student's enrollment",
        required: false,
        name: "academic_year"
      )

      params(:query, :string, "The grade of the student's enrollment",
        required: false,
        name: "grade"
      )

      params(:query, :string, "The board medium of the student's enrollment",
        required: false,
        name: "board_medium"
      )
    end

    response(200, "OK", Schema.ref(:EnrollmentRecords))
  end

  def index(conn, params) do
    query =
      from(m in EnrollmentRecord,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from(u in acc, where: field(u, ^atom) == ^value)
        end
      end)

    enrollment_record = Repo.all(query)
    render(conn, :index, enrollment_record: enrollment_record)
  end

  swagger_path :create do
    post("/api/enrollment-record")

    parameters do
      body(:body, Schema.ref(:EnrollmentRecord), "Enrollment record to create", required: true)
    end

    response(201, "Created", Schema.ref(:EnrollmentRecord))
  end

  def create(conn, params) do
    case EnrollmentRecords.get_enrollment_record_by_params(
           params["user_id"],
           params["group_id"],
           params["group_type"],
           params["academic_year"]
         ) do
      nil ->
        create_new_enrollment_record(conn, params)

      existing_enrollment_record ->
        update_existing_enrollment_record(conn, existing_enrollment_record, params)
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
    enrollment_record = EnrollmentRecords.get_enrollment_record!(id)
    render(conn, :show, enrollment_record: enrollment_record)
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
    enrollment_record = EnrollmentRecords.get_enrollment_record!(params["id"])

    with {:ok, %EnrollmentRecord{} = enrollment_record} <-
           EnrollmentRecords.update_enrollment_record(enrollment_record, params) do
      render(conn, :show, enrollment_record: enrollment_record)
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
    enrollment_record = EnrollmentRecords.get_enrollment_record!(id)

    with {:ok, %EnrollmentRecord{}} <-
           EnrollmentRecords.delete_enrollment_record(enrollment_record) do
      send_resp(conn, :no_content, "")
    end
  end

  def create_new_enrollment_record(conn, params) do
    with {:ok, %EnrollmentRecord{} = enrollment_record} <-
           EnrollmentRecords.create_enrollment_record(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        ~p"/api/enrollment-record/#{enrollment_record}"
      )
      |> render(:show, enrollment_record: enrollment_record)
    end
  end

  defp update_existing_enrollment_record(conn, existing_enrollment_record, params) do
    with {:ok, %EnrollmentRecord{} = enrollment_record} <-
           EnrollmentRecords.update_enrollment_record(existing_enrollment_record, params) do
      conn
      |> put_status(:ok)
      |> render(:show, enrollment_record: enrollment_record)
    end
  end
end
