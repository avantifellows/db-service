defmodule DbserviceWeb.StudentExamRecordController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.StudentExamRecords
  alias Dbservice.Exams.StudentExamRecord

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.StudentExamRecord, as: SwaggerStudentExamRecord

  def swagger_definitions do
    Map.merge(
      SwaggerStudentExamRecord.student_exam_record(),
      SwaggerStudentExamRecord.student_exam_records()
    )
  end

  swagger_path :index do
    get("/api/student-exam-record")

    parameters do
      params(:query, :integer, "The id of the student", required: false, name: "student_id")
      params(:query, :integer, "The id of the exam", required: false, name: "exam_id")
    end

    response(200, "OK", Schema.ref(:StudentExamRecords))
  end

  def index(conn, params) do
    query =
      from(m in StudentExamRecord,
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

    student_exam_record = Repo.all(query)
    render(conn, "index.json", student_exam_record: student_exam_record)
  end

  swagger_path :create do
    post("/api/student-exam-record")

    parameters do
      body(:body, Schema.ref(:StudentExamRecord), "Student Exam Record to create", required: true)
    end

    response(201, "Created", Schema.ref(:StudentExamRecord))
  end

  def create(conn, params) do
    case StudentExamRecords.get_student_exam_records_by_student_id_and_application_number(
           params["student_id"],
           params["application_number"]
         ) do
      nil ->
        create_new_student_exam_record(conn, params)

      existing_student_exam_record ->
        update_existing_student_exam_record(conn, existing_student_exam_record, params)
    end
  end

  swagger_path :show do
    get("/api/student-exam-record/{recordId}")

    parameters do
      recordId(:path, :integer, "The id of the record", required: true)
    end

    response(200, "OK", Schema.ref(:StudentExamRecord))
  end

  def show(conn, %{"id" => id}) do
    student_exam_record = StudentExamRecords.get_student_exam_record!(id)
    render(conn, "show.json", student_exam_record: student_exam_record)
  end

  swagger_path :update do
    patch("/api/student-exam-record/{recordId}")

    parameters do
      recordId(:path, :integer, "The id of the record", required: true)
      body(:body, Schema.ref(:StudentExamRecord), "Record to create", required: true)
    end

    response(200, "Updated", Schema.ref(:StudentExamRecord))
  end

  def update(conn, params) do
    student_exam_record = StudentExamRecords.get_student_exam_record!(params["id"])

    with {:ok, %StudentExamRecord{} = student_exam_record} <-
           StudentExamRecords.update_student_exam_record(student_exam_record, params) do
      render(conn, "show.json", student_exam_record: student_exam_record)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/student-exam-record/{recordId}")

    parameters do
      recordId(:path, :integer, "The id of the record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    student_exam_record = StudentExamRecords.get_student_exam_record!(id)

    with {:ok, %StudentExamRecord{}} <-
           StudentExamRecords.delete_student_exam_record(student_exam_record) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_student_exam_record(conn, params) do
    with {:ok, %StudentExamRecord{} = student_exam_record} <-
           StudentExamRecords.create_student_exam_record(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        ~p"/api/student-exam-record/#{student_exam_record}"
      )
      |> render("show.json", student_exam_record: student_exam_record)
    end
  end

  defp update_existing_student_exam_record(conn, existing_student_exam_record, params) do
    with {:ok, %StudentExamRecord{} = student_exam_record} <-
           StudentExamRecords.update_student_exam_record(existing_student_exam_record, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", student_exam_record: student_exam_record)
    end
  end
end
