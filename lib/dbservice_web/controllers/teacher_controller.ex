defmodule DbserviceWeb.TeacherController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Users.Teacher

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Teacher, as: SwaggerSchemaTeacher

  def swagger_definitions do
    Map.merge(
      Map.merge(
        SwaggerSchemaTeacher.teacher(),
        SwaggerSchemaTeacher.teachers()
      ),
      Map.merge(
        SwaggerSchemaTeacher.teacher_registration(),
        SwaggerSchemaTeacher.teacher_with_user()
      )
    )
  end

  swagger_path :index do
    get("/api/teacher?designation=Vice Principal")
    response(200, "OK", Schema.ref(:Teachers))
  end

  def index(conn, params) do
    query =
      from m in Teacher,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from u in acc, where: field(u, ^atom) == ^value
        end
      end)

    teacher = Repo.all(query) |> Repo.preload([:user])
    render(conn, "index.json", teacher: teacher)
  end

  swagger_path :create do
    post("/api/teacher")

    parameters do
      body(:body, Schema.ref(:Teacher), "Teacher to create", required: true)
    end

    response(201, "Created", Schema.ref(:Teacher))
  end

  def create(conn, params) do
    with {:ok, %Teacher{} = teacher} <- Users.create_teacher(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.teacher_path(conn, :show, teacher))
      |> render("show.json", teacher: teacher)
    end
  end

  swagger_path :show do
    get("/api/teacher/{id}")

    parameters do
      id(:path, :integer, "The id of the teacher record", required: true)
    end

    response(200, "OK", Schema.ref(:Teacher))
  end

  def show(conn, %{"id" => id}) do
    teacher = Users.get_teacher!(id)
    render(conn, "show.json", teacher: teacher)
  end

  def update(conn, params) do
    teacher = Users.get_teacher!(params["id"])

    with {:ok, %Teacher{} = teacher} <- Users.update_teacher(teacher, params) do
      render(conn, "show.json", teacher: teacher)
    end
  end

  swagger_path :update do
    patch("/api/teacher/{id}")

    parameters do
      id(:path, :integer, "The id of the teacher record", required: true)
      body(:body, Schema.ref(:Teacher), "Teacher to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Teacher))
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/teacher/{id}")

    parameters do
      id(:path, :integer, "The id of the teacher record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    teacher = Users.get_teacher!(id)

    with {:ok, %Teacher{}} <- Users.delete_teacher(teacher) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :register do
    post("/api/teacher/register")

    parameters do
      body(:body, Schema.ref(:TeacherRegistration), "Teacher to create along with user",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:TeacherWithUser))
  end

  def register(conn, params) do
    with {:ok, %Teacher{} = teacher} <- Users.create_teacher_with_user(params) do
      conn
      |> put_status(:created)
      |> render("show.json", teacher: teacher)
    end
  end

  def update_teacher_with_user(conn, params) do
    teacher = Users.get_teacher!(params["id"])
    user = Users.get_user!(teacher.user_id)

    with {:ok, %Teacher{} = teacher} <- Users.update_teacher_with_user(teacher, user, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", teacher: teacher)
    end
  end
end
