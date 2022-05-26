defmodule DbserviceWeb.TeacherController do
  use DbserviceWeb, :controller

  alias Dbservice.Users
  alias Dbservice.Users.Teacher

  action_fallback DbserviceWeb.FallbackController

  def index(conn, _params) do
    teacher = Users.list_teacher()
    render(conn, "index.json", teacher: teacher)
  end

  def create(conn, %{"teacher" => teacher_params}) do
    with {:ok, %Teacher{} = teacher} <- Users.create_teacher(teacher_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.teacher_path(conn, :show, teacher))
      |> render("show.json", teacher: teacher)
    end
  end

  def show(conn, %{"id" => id}) do
    teacher = Users.get_teacher!(id)
    render(conn, "show.json", teacher: teacher)
  end

  def update(conn, %{"id" => id, "teacher" => teacher_params}) do
    teacher = Users.get_teacher!(id)

    with {:ok, %Teacher{} = teacher} <- Users.update_teacher(teacher, teacher_params) do
      render(conn, "show.json", teacher: teacher)
    end
  end

  def delete(conn, %{"id" => id}) do
    teacher = Users.get_teacher!(id)

    with {:ok, %Teacher{}} <- Users.delete_teacher(teacher) do
      send_resp(conn, :no_content, "")
    end
  end
end
