defmodule DbserviceWeb.StudentController do
  use DbserviceWeb, :controller

  alias Dbservice.Users
  alias Dbservice.Users.Student

  action_fallback DbserviceWeb.FallbackController

  def index(conn, _params) do
    student = Users.list_student()
    render(conn, "index.json", student: student)
  end

  def create(conn, params) do
    with {:ok, %Student{} = student} <- Users.create_student(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.student_path(conn, :show, student))
      |> render("show.json", student: student)
    end
  end

  def show(conn, %{"id" => id}) do
    student = Users.get_student!(id)
    render(conn, "show.json", student: student)
  end

  def update(conn, params) do
    student = Users.get_student!(params["id"])

    with {:ok, %Student{} = student} <- Users.update_student(student, params) do
      render(conn, "show.json", student: student)
    end
  end

  def delete(conn, %{"id" => id}) do
    student = Users.get_student!(id)

    with {:ok, %Student{}} <- Users.delete_student(student) do
      send_resp(conn, :no_content, "")
    end
  end
end
