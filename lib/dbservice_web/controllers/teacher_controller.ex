defmodule DbserviceWeb.TeacherController do
  use DbserviceWeb, :controller

  alias Dbservice.Users
  alias Dbservice.Users.Teacher

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  def swagger_definitions do
    %{
      Teacher:
        swagger_schema do
          title("Teacher")
          description("A teacher in the application")

          properties do
            designation(:string, "Designation")
            subject(:string, "Core subject")
            grade(:string, "Grade")
            user_id(:integer, "User ID for the teacher")
            school_id(:integer, "School ID for the teacher")
            program_manager_id(:integer, "Program manager user ID for the teacher")
          end

          example(%{
            designation: "Vice Principal",
            subject: "Mats",
            grade: "12",
            user_id: 1,
            school_id: 2,
            program_manager_id: 3,
          })
        end,
      Teachers:
        swagger_schema do
          title("Teachers")
          description("All teachers in the application")
          type(:array)
          items(Schema.ref(:Teacher))
        end
    }
  end

  swagger_path :index do
    get("/api/teacher")
    response(200, "OK", Schema.ref(:Teachers))
  end

  def index(conn, _params) do
    teacher = Users.list_teacher()
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
    get("/api/teacher/{teacherId}")

    parameters do
      teacherId(:path, :integer, "The id of the teacher", required: true)
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
    patch("/api/teacher/{teacherId}")

    parameters do
      teacherId(:path, :integer, "The id of the teacher", required: true)
      body(:body, Schema.ref(:Teacher), "Teacher to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Teacher))
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/teacher/{teacherId}")

    parameters do
      teacherId(:path, :integer, "The id of the teacher", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    teacher = Users.get_teacher!(id)

    with {:ok, %Teacher{}} <- Users.delete_teacher(teacher) do
      send_resp(conn, :no_content, "")
    end
  end
end
