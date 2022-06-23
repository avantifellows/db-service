defmodule DbserviceWeb.EnrollmentRecordController do
  use DbserviceWeb, :controller

  alias Dbservice.Schools
  alias Dbservice.Schools.EnrollmentRecord

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  def swagger_definitions do
    %{
      EnrollmentRecord:
        swagger_schema do
          title("EnrollmentRecord")
          description("An enrollment record for the student")

          properties do
            grade(:string, "Grade")
            academic_year(:string, "Academic Year")
            is_current(:boolean, "Is current enrollment record for student")
            student_id(:integer, "Student ID that the program enrollment belongs to")
            school_id(:integer, "School ID that the program enrollment belongs to")
          end

          example(%{
            grade: "7",
            academic_year: "2022",
            is_current: true,
            student_id: 1,
            school_id: 1
          })
        end,
      EnrollmentRecords:
        swagger_schema do
          title("EnrollmentRecords")
          description("All enrollment records")
          type(:array)
          items(Schema.ref(:EnrollmentRecord))
        end
    }
  end

  swagger_path :index do
    get("/api/enrollment-record")
    response(200, "OK", Schema.ref(:EnrollmentRecords))
  end

  def index(conn, _params) do
    enrollment_record = Schools.list_enrollment_record()
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
