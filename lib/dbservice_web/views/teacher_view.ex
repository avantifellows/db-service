defmodule DbserviceWeb.TeacherView do
  use DbserviceWeb, :view
  alias DbserviceWeb.UserView
  alias Dbservice.Repo

  def render("index.json", %{teacher: teachers}) do
    Enum.map(teachers, &teacher_json/1)
  end

  def render("show.json", %{teacher: teacher}) do
    teacher_json(teacher)
  end

  def render("show_with_user.json", %{teacher: teachers}) do
    Enum.map(teachers, &teacher_with_user_json/1)
  end

  def teacher_json(%{__meta__: _, user: user} = teacher) do
    teacher = Repo.preload(teacher, :user)

    %{
      id: teacher.id,
      designation: teacher.designation,
      teacher_id: teacher.teacher_id,
      subject_id: teacher.subject_id,
      user: UserView.user_json(user)
    }
  end

  def teacher_with_user_json(%{__meta__: _, user: user} = teacher) do
    teacher = Repo.preload(teacher, :user)
    %{
      id: teacher.id,
      designation: teacher.designation,
      teacher_id: teacher.teacher_id,
      subject_id: teacher.subject_id,
      user: UserView.user_json(user),
      is_af_teacher: teacher.is_af_teacher
    }
  end
end
