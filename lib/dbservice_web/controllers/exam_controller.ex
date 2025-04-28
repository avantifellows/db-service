defmodule DbserviceWeb.ExamController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Exams
  alias Dbservice.Exams.Exam

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Exam, as: SwaggerSchemaExam

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaExam.exam(),
      SwaggerSchemaExam.exams()
    )
  end

  swagger_path :index do
    get("/api/exam")

    parameters do
      params(:query, :string, "The name of the exam", required: false, name: "name")
    end

    response(200, "OK", Schema.ref(:Exams))
  end

  def index(conn, params) do
    query =
      from(m in Exam,
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

    exam = Repo.all(query)
    render(conn, "index.json", exam: exam)
  end

  swagger_path :create do
    post("/api/exam")

    parameters do
      body(:body, Schema.ref(:Exam), "Exam to create", required: true)
    end

    response(201, "Created", Schema.ref(:Exam))
  end

  def create(conn, params) do
    case Exams.get_exam_by_name(params["name"]) do
      nil ->
        create_new_exam(conn, params)

      existing_exam ->
        update_existing_exam(conn, existing_exam, params)
    end
  end

  swagger_path :show do
    get("/api/exam/{examId}")

    parameters do
      examId(:path, :integer, "The id of the exam", required: true)
    end

    response(200, "OK", Schema.ref(:Exam))
  end

  def show(conn, %{"id" => id}) do
    exam = Exams.get_exam!(id)
    render(conn, "show.json", exam: exam)
  end

  swagger_path :update do
    patch("/api/exam/{examId}")

    parameters do
      examId(:path, :integer, "The id of the exam", required: true)
      body(:body, Schema.ref(:Exam), "Exam to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Exam))
  end

  def update(conn, params) do
    exam = Exams.get_exam!(params["id"])

    with {:ok, %Exam{} = exam} <- Exams.update_exam(exam, params) do
      render(conn, "show.json", exam: exam)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/exam/{examId}")

    parameters do
      examId(:path, :integer, "The id of the exam", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    exam = Exams.get_exam!(id)

    with {:ok, %Exam{}} <- Exams.delete_exam(exam) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_exam(conn, params) do
    with {:ok, %Exam{} = exam} <- Exams.create_exam(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/exam/#{exam}")
      |> render("show.json", exam: exam)
    end
  end

  defp update_existing_exam(conn, existing_exam, params) do
    with {:ok, %Exam{} = exam} <- Exams.update_exam(existing_exam, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", exam: exam)
    end
  end
end
