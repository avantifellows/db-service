defmodule DbserviceWeb.TeacherJSON do
  alias DbserviceWeb.UserJSON

  def index(%{teacher: teacher}) do
    for(t <- teacher, do: render(t))
  end

  def show(%{teacher: teacher}) do
    render(teacher)
  end

  def show_teacher_with_user(%{teacher: teacher}) do
    teacher_with_user(teacher)
  end

  def render(teacher) do
    teacher = Dbservice.Repo.preload(teacher, :user)
    %{
      id: teacher.id,
      designation: teacher.designation,
      teacher_id: teacher.teacher_id,
      subject_id: teacher.subject_id,
      user: if(teacher.user, do: UserJSON.render(teacher.user), else: nil)
    }
  end

  def teacher_with_user(teacher) do
    teacher = Dbservice.Repo.preload(teacher, :user)

    %{
      id: teacher.id,
      designation: teacher.designation,
      teacher_id: teacher.teacher_id,
      subject_id: teacher.subject_id,
      is_af_teacher: teacher.is_af_teacher,
      user: if(teacher.user, do: UserJSON.render(teacher.user), else: nil)
    }
  end
end
