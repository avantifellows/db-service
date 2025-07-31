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
        SwaggerSchemaTeacher.teacher_with_user(),
        SwaggerSchemaTeacher.teacher_batch_assignment()
      )
    )
  end

  swagger_path :index do
    get("/api/teacher")

    parameters do
      params(:query, :string, "The ID the teacher",
        required: false,
        name: "teacher_id"
      )

      params(:query, :string, "The designation the teacher", required: false, name: "designation")
    end

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

    teacher = Repo.all(query)
    render(conn, :index, teacher: teacher)
  end

  swagger_path :create do
    post("/api/teacher")

    parameters do
      body(:body, Schema.ref(:TeacherWithUser), "Teacher to create along with user",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:TeacherWithUser))
  end

  def create(conn, params) do
    case Users.get_teacher_by_teacher_id(params["teacher_id"]) do
      nil ->
        create_teacher_with_user(conn, params)

      existing_teacher ->
        update_existing_teacher_with_user(conn, existing_teacher, params)
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
    render(conn, :show, teacher: teacher)
  end

  def update(conn, params) do
    teacher = Users.get_teacher!(params["id"])

    with {:ok, %Teacher{} = teacher} <- update_existing_teacher_with_user(conn, teacher, params) do
      render(conn, :show, teacher: teacher)
    end
  end

  swagger_path :update do
    patch("/api/teacher/{id}")

    parameters do
      id(:path, :integer, "The id of the teacher record", required: true)
      body(:body, Schema.ref(:Teacher), "Teacher to update along with user", required: true)
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

  def update_teacher_with_user(conn, params) do
    teacher = Users.get_teacher!(params["id"])
    user = Users.get_user!(teacher.user_id)

    with {:ok, %Teacher{} = teacher} <- Users.update_teacher_with_user(teacher, user, params) do
      conn
      |> put_status(:ok)
      |> render(:show, teacher: teacher)
    end
  end

  defp create_teacher_with_user(conn, params) do
    with {:ok, %Teacher{} = teacher} <- Users.create_teacher_with_user(params) do
      conn
      |> put_status(:created)
      |> render(:show, teacher: teacher)
    end
  end

  defp update_existing_teacher_with_user(conn, existing_teacher, params) do
    user = Users.get_user!(existing_teacher.user_id)

    with {:ok, %Teacher{} = teacher} <-
           Users.update_teacher_with_user(existing_teacher, user, params) do
      conn
      |> put_status(:ok)
      |> render(:show, teacher: teacher)
    end
  end

  swagger_path :assign_batch do
    patch("/api/teacher/batch/assign")

    parameters do
      body(:body, Schema.ref(:TeacherBatchAssignment), "Teacher batch assignment details",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:Teacher))
  end

  def assign_batch(conn, params) do
    case Dbservice.DataImport.TeacherBatchAssignment.process_teacher_batch_assignment(params) do
      {:ok, _message} ->
        # Get the updated teacher for response
        teacher = Users.get_teacher_by_teacher_id(params["teacher_id"])
        teacher_with_user = Repo.preload(teacher, [:user])
        render(conn, :show, teacher: teacher_with_user)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
end
