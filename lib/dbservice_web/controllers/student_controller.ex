defmodule DbserviceWeb.StudentController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Users.Student

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Student, as: SwaggerSchemaStudent

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      Map.merge(
        SwaggerSchemaStudent.student(),
        SwaggerSchemaStudent.students()
      ),
      Map.merge(
        SwaggerSchemaStudent.student_registration(),
        SwaggerSchemaStudent.student_with_user()
      )
    )
  end

  swagger_path :index do
    get("/api/student")

    parameters do
      params(:query, :string, "The id of the student", required: false, name: "student_id")
      params(:query, :string, "The stream of the student", required: false, name: "stream")

      params(:query, :string, "The father's name of the student",
        required: false,
        name: "father_name"
      )
    end

    response(200, "OK", Schema.ref(:Students))
  end

  def index(conn, params) do
    query =
      from(m in Student,
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

    student = Repo.all(query) |> Repo.preload([:user])
    render(conn, "index.json", student: student)
  end

  swagger_path :create do
    post("/api/student")

    parameters do
      body(:body, Schema.ref(:Student), "Student to create", required: true)
    end

    response(201, "Created", Schema.ref(:Student))
  end

  def create(conn, params) do
    case Students.get_student_by_student_id(params["student_id"]) do
      nil ->
        create_new_student(conn, params)

      existing_student ->
        update_existing_student(conn, existing_student, params)
    end
  end

  swagger_path :show do
    get("/api/student/{id}")

    parameters do
      id(:path, :integer, "The id of the student record", required: true)
    end

    response(200, "OK", Schema.ref(:Student))
  end

  def show(conn, %{"id" => id}) do
    student = Users.get_student!(id)
    render(conn, "show.json", student: student)
  end

  swagger_path :update do
    patch("/api/student/{id}")

    parameters do
      id(:path, :integer, "The id of the student record", required: true)
      body(:body, Schema.ref(:Student), "Student to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Student))
  end

  def update(conn, params) do
    student = Users.get_student!(params["id"])

    with {:ok, %Student{} = student} <- Users.update_student(student, params) do
      render(conn, "show.json", student: student)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/student/{id}")

    parameters do
      id(:path, :integer, "The id of the student record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    student = Users.get_student!(id)

    with {:ok, %Student{}} <- Users.delete_student(student) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :register do
    post("/api/student/register")

    parameters do
      body(:body, Schema.ref(:StudentRegistration), "Student to create along with user",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:StudentWithUser))
  end

  def register(conn, params) do
    with {:ok, %Student{} = student} <- Users.create_student_with_user(params) do
      conn
      |> put_status(:created)
      |> render("show.json", student: student)
    end
  end

  def update_student_with_user(conn, params) do
    student = Users.get_student!(params["id"])
    user = Users.get_user!(student.user_id)

    with {:ok, %Student{} = student} <- Users.update_student_with_user(student, user, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", student: student)
    end
  end

  defp create_new_student(conn, params) do
    with {:ok, %Student{} = student} <- Users.create_student(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.student_path(conn, :show, student))
      |> render("show.json", student: student)
    end
  end

  defp update_existing_student(conn, existing_student, params) do
    with {:ok, %Student{} = student} <- Users.update_student(existing_student, params) do
      conn
      |> put_status(:ok)
      |> render(conn, "show.json", student: student)
    end
  end
end
