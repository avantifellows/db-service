defmodule DbserviceWeb.GradeController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Grades
  alias Dbservice.Grades.Grade

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Grade, as: SwaggerSchemaGrade

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaGrade.grade(),
      SwaggerSchemaGrade.grades()
    )
  end

  swagger_path :index do
    get("/api/grade")

    parameters do
      params(:query, :string, "The grade in school",
        required: false,
        name: "number"
      )
    end

    response(200, "OK", Schema.ref(:Grades))
  end

  def index(conn, params) do
    query =
      from(m in Grade,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        if String.to_existing_atom(key) == :offset do
          acc
        else
          if String.to_existing_atom(key) == :limit do
            acc
          else
            if value == "" or value == "undefined" do
              acc
            else
              from(u in acc, where: field(u, ^String.to_existing_atom(key)) == ^value)
            end
          end
        end
      end)

    grade = Repo.all(query)
    render(conn, "index.json", grade: grade)
  end

  swagger_path :create do
    post("/api/grade")

    parameters do
      body(:body, Schema.ref(:Grade), "Grade to create", required: true)
    end

    response(201, "Created", Schema.ref(:Grade))
  end

  def create(conn, params) do
    case params do
      %{"_json" => grade_list} ->
        # Handles the case where params is a list of grades
        create_grades(conn, grade_list)

      _ ->
        # Handles the case where params is a single grade
        create_grade(conn, params)
    end
  end

  swagger_path :show do
    get("/api/grade/{gradeId}")

    parameters do
      gradeId(:path, :integer, "The id of the grade record", required: true)
    end

    response(200, "OK", Schema.ref(:Grade))
  end

  def show(conn, %{"id" => id}) do
    grade = Grades.get_grade!(id)
    render(conn, "show.json", grade: grade)
  end

  swagger_path :update do
    patch("/api/grade/{gradeId}")

    parameters do
      gradeId(:path, :integer, "The id of the grade record", required: true)
      body(:body, Schema.ref(:Grade), "Grade to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Grade))
  end

  def update(conn, params) do
    grade = Grades.get_grade!(params["id"])

    with {:ok, %Grade{} = grade} <- Grades.update_grade(grade, params) do
      render(conn, "show.json", grade: grade)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/grade/{gradeId}")

    parameters do
      gradeId(:path, :integer, "The id of the grade record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    grade = Grades.get_grade!(id)

    with {:ok, %Grade{}} <- Grades.delete_grade(grade) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_grades(conn, grade_list) do
    case Grades.create_grades(grade_list) do
      {:ok, grades} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.grade_path(conn, :index))
        |> render("grade.json", grade: grades)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(DbserviceWeb.ChangesetView, "error.json", changeset: changeset)
    end
  end

  defp create_grade(conn, params) do
    with {:ok, %Grade{} = grade} <- Grades.create_grade(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.grade_path(conn, :show, grade))
      |> render("show.json", grade: grade)
    end
  end
end
