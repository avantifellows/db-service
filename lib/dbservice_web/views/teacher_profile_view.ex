defmodule DbserviceWeb.TeacherProfileView do
  use DbserviceWeb, :view
  alias DbserviceWeb.UserProfileView
  alias Dbservice.Repo

  def render("index.json", %{teacher_profile: teacher_profile}) do
    Enum.map(teacher_profile, &teacher_profile_json/1)
  end

  def render("show.json", %{teacher_profile: teacher_profile}) do
    teacher_profile_json(teacher_profile)
  end

  def render("show_with_user_profile.json", %{teacher_profile: teacher_profile}) do
    Enum.map(teacher_profile, &teacher_profile_with_user_profile_json/1)
  end

  def teacher_profile_json(%{user_profile: user_profile} = teacher_profile) do
    teacher_profile = Repo.preload(teacher_profile, :user_profile)

    %{
      id: teacher_profile.id,
      teacher_id: teacher_profile.teacher_id,
      teacher_fk: teacher_profile.teacher_fk,
      school: teacher_profile.school,
      program_manager: teacher_profile.program_manager,
      avg_rating: teacher_profile.avg_rating,
      user_profile: UserProfileView.user_profile_json(user_profile)
    }
  end

  def teacher_profile_with_user_profile_json(%{user_profile: user_profile} = teacher_profile) do
    %{
      id: teacher_profile.id,
      teacher_id: teacher_profile.teacher_id,
      teacher_fk: teacher_profile.teacher_fk,
      school: teacher_profile.school,
      program_manager: teacher_profile.program_manager,
      avg_rating: teacher_profile.avg_rating,
      user_profile: UserProfileView.user_profile_json(user_profile)
    }
  end
end
