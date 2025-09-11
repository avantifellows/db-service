defmodule DbserviceWeb.ExamOccurrenceController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Exams
  alias Dbservice.Exams.ExamOccurrence

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.ExamOccurrence, as: SwaggerSchemaExamOccurrence

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaExamOccurrence.exam_occurrence(),
      SwaggerSchemaExamOccurrence.exam_occurrences()
    )
  end

  swagger_path :index do
    get("/api/exam_occurrence")

    parameters do
      exam_id(:query, :integer, "The exam ID", required: false)
      year(:query, :integer, "The year", required: false)
    end

    response(200, "OK", Schema.ref(:ExamOccurrences))
  end

  def index(conn, params) do
    query =
      from(eo in ExamOccurrence,
        order_by: [asc: eo.id],
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

    exam_occurrence = Repo.all(query)
    render(conn, :index, exam_occurrence: exam_occurrence)
  end

  swagger_path :show do
    get("/api/exam_occurrence/{id}")

    parameters do
      id(:path, :integer, "The ID of the exam occurrence", required: true)
    end

    response(200, "OK", Schema.ref(:ExamOccurrence))
    response(404, "Not Found")
  end

  def show(conn, %{"id" => id}) do
    exam_occurrence = Exams.get_exam_occurrence!(id)
    render(conn, :show, exam_occurrence: exam_occurrence)
  end

  swagger_path :create do
    post("/api/exam_occurrence")

    parameters do
      exam_occurrence(:body, Schema.ref(:ExamOccurrence), "The exam occurrence to create",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:ExamOccurrence))
    response(422, "Unprocessable Entity")
  end

  def create(conn, params) do
    # Extract exam_occurrence parameters - handle both nested and direct parameter formats
    exam_occurrence_params = params["exam_occurrence"] || params
    
    case Exams.create_exam_occurrence(exam_occurrence_params) do
      {:ok, exam_occurrence} ->
        conn
        |> put_status(:created)
        |> render(:show, exam_occurrence: exam_occurrence)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :update do
    put("/api/exam_occurrence/{id}")

    parameters do
      id(:path, :integer, "The ID of the exam occurrence", required: true)

      exam_occurrence(:body, Schema.ref(:ExamOccurrence), "The exam occurrence updates",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:ExamOccurrence))
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id} = params) do
    # Extract exam_occurrence parameters - handle both nested and direct parameter formats
    exam_occurrence_params = params["exam_occurrence"] || Map.delete(params, "id")
    exam_occurrence = Exams.get_exam_occurrence!(id)

    case Exams.update_exam_occurrence(exam_occurrence, exam_occurrence_params) do
      {:ok, exam_occurrence} ->
        render(conn, :show, exam_occurrence: exam_occurrence)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/exam_occurrence/{id}")

    parameters do
      id(:path, :integer, "The ID of the exam occurrence", required: true)
    end

    response(204, "No Content")
    response(404, "Not Found")
  end

  def delete(conn, %{"id" => id}) do
    exam_occurrence = Exams.get_exam_occurrence!(id)
    {:ok, _exam_occurrence} = Exams.delete_exam_occurrence(exam_occurrence)

    send_resp(conn, :no_content, "")
  end
end
