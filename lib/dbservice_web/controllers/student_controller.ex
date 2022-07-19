defmodule DbserviceWeb.StudentController do
  use DbserviceWeb, :controller

  alias Dbservice.Users
  alias Dbservice.Users.Student

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  def swagger_definitions do
    %{
      Student:
        swagger_schema do
          title("Student")
          description("A student in the application")

          properties do
            uuid(:string, "UUID for the student")
            father_name(:string, "Father's name")
            father_phone(:string, "Father's phone number")
            mother_name(:string, "Mother's name")
            mother_phone(:string, "Mother's phone number")
            category(:string, "Category")
            stream(:string, "Stream")
            user_id(:integer, "User ID for the student")
            group_id(:integer, "Group ID for the student")
          end

          example(%{
            uuid: "120180101057",
            father_name: "Narayan Pandey",
            father_phone: "8989898989",
            mother_name: "Lakshmi Pandey",
            mother_phone: "9998887777",
            category: "general",
            stream: "PCB",
            user_id: 1,
            group_id: 2
          })
        end,
      Students:
        swagger_schema do
          title("Students")
          description("All students in the application")
          type(:array)
          items(Schema.ref(:Student))
        end
    }
  end

  swagger_path :index do
    get("/api/student")
    response(200, "OK", Schema.ref(:Students))
  end

  def index(conn, _params) do
    student = Users.list_student()
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
    with {:ok, %Student{} = student} <- Users.create_student(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.student_path(conn, :show, student))
      |> render("show.json", student: student)
    end
  end

  swagger_path :show do
    get("/api/student/{studentId}")

    parameters do
      studentId(:path, :integer, "The id of the student", required: true)
    end

    response(200, "OK", Schema.ref(:Student))
  end

  def show(conn, %{"id" => id}) do
    student = Users.get_student!(id)
    render(conn, "show.json", student: student)
  end

  swagger_path :update do
    patch("/api/student/{studentId}")

    parameters do
      studentId(:path, :integer, "The id of the student", required: true)
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
    PhoenixSwagger.Path.delete("/api/student/{studentId}")

    parameters do
      studentId(:path, :integer, "The id of the student", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    student = Users.get_student!(id)

    with {:ok, %Student{}} <- Users.delete_student(student) do
      send_resp(conn, :no_content, "")
    end
  end

  def register(conn, params) do
    with {:ok, %Student{} = student} <- Users.create_student_with_user(params) do
      conn
      |> put_status(:created)
      |> render("show_with_user.json", student: student)
    end
  end
end
