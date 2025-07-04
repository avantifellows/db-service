defmodule DbserviceWeb.TeacherProfileJSON do
  alias DbserviceWeb.UserProfileJSON

  def index(%{teacher_profile: teacher_profile}) do
    for(tp <- teacher_profile, do: render(tp))
  end

  def show(%{teacher_profile: teacher_profile}) do
    render(teacher_profile)
  end

  def show_teacher_profile_with_user_profile(%{teacher_profile: teacher_profile}) do
    teacher_profile_with_user_profile(teacher_profile)
  end

  def render(teacher_profile) do
    %{
      id: teacher_profile.id,
      teacher_id: teacher_profile.teacher_id,
      teacher_fk: teacher_profile.teacher_fk,
      school: teacher_profile.school,
      program_manager: teacher_profile.program_manager,
      avg_rating: teacher_profile.avg_rating,
      user_profile_id: teacher_profile.user_profile_id
    }
  end

  def teacher_profile_with_user_profile(teacher_profile) do
    teacher_profile = Dbservice.Repo.preload(teacher_profile, :user_profile)
    %{
      id: teacher_profile.id,
      teacher_id: teacher_profile.teacher_id,
      teacher_fk: teacher_profile.teacher_fk,
      school: teacher_profile.school,
      program_manager: teacher_profile.program_manager,
      avg_rating: teacher_profile.avg_rating,
      user_profile_id: teacher_profile.user_profile_id,
      user_profile:
        if(teacher_profile.user_profile,
          do: UserProfileJSON.render(teacher_profile.user_profile),
          else: nil
        )
    }
  end
end
