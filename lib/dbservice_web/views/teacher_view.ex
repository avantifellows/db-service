defmodule DbserviceWeb.TeacherView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TeacherView

  def render("index.json", %{teacher: teacher}) do
    %{data: render_many(teacher, TeacherView, "teacher.json")}
  end

  def render("show.json", %{teacher: teacher}) do
    %{data: render_one(teacher, TeacherView, "teacher.json")}
  end

  def render("teacher.json", %{teacher: teacher}) do
    %{
      id: teacher.id,
      designation: teacher.designation,
      subject: teacher.subject,
      grade: teacher.grade
    }
  end
end
