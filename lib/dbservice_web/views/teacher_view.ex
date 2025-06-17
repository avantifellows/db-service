defmodule DbserviceWeb.TeacherView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TeacherView
  alias DbserviceWeb.UserView
  alias Dbservice.Repo

  def render("index.json", %{teacher: teacher}) do
    render_many(teacher, TeacherView, "teacher.json")
  end

  def render("show.json", %{teacher: teacher}) do
    render_one(teacher, TeacherView, "teacher.json")
  end

  def render("show_with_user.json", %{teacher: teacher}) do
    render_many(teacher, TeacherView, "teacher_with_user.json")
  end

  def render("teacher.json", %{teacher: teacher}) do
    teacher = Repo.preload(teacher, :user)

    %{
      id: teacher.id,
      designation: teacher.designation,
      teacher_id: teacher.teacher_id,
      subject_id: teacher.subject_id,
      user: render_one(teacher.user, UserView, "user.json")
    }
  end

  def render("teacher_with_user.json", %{teacher: teacher}) do
    %{
      id: teacher.id,
      designation: teacher.designation,
      teacher_id: teacher.teacher_id,
      subject_id: teacher.subject_id,
      user: render_one(teacher.user, UserView, "user.json"),
      is_af_teacher: teacher.is_af_teacher
    }
  end
end
