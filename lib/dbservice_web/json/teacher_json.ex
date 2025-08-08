defmodule DbserviceWeb.TeacherJSON do
  alias DbserviceWeb.UserJSON
  alias Dbservice.Repo

  def index(%{teacher: teacher}) do
    for(t <- teacher, do: render(t))
  end

  def show(%{teacher: teacher}) do
    render(teacher)
  end

  def render(teacher) do
    teacher = Repo.preload(teacher, [:subject, :user])

    %{
      id: teacher.id,
      designation: teacher.designation,
      teacher_id: teacher.teacher_id,
      subject_id: teacher.subject_id,
      is_af_teacher: teacher.is_af_teacher,
      user_id: teacher.user_id,
      user: if(teacher.user, do: UserJSON.render(teacher.user), else: nil)
    }
  end
end
