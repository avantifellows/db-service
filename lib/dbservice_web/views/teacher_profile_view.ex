defmodule DbserviceWeb.TeacherProfileView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TeacherProfileView
  alias DbserviceWeb.UserProfileView
  alias Dbservice.Repo

  def render("index.json", %{teacher_profile: teacher_profile}) do
    render_many(teacher_profile, TeacherProfileView, "teacher_profile.json")
  end

  def render("show.json", %{teacher_profile: teacher_profile}) do
    render_one(teacher_profile, TeacherProfileView, "teacher_profile.json")
  end

  def render("show_with_user_profile.json", %{teacher_profile: teacher_profile}) do
    render_many(teacher_profile, TeacherProfileView, "teacher_profile_with_user_profile.json")
  end

  def render("teacher_profile.json", %{teacher_profile: teacher_profile}) do
    teacher_profile = Repo.preload(teacher_profile, :user_profile)

    %{
      id: teacher_profile.id,
      user_profile_id: teacher_profile.user_profile_id,
      teacher_id: teacher_profile.teacher_id,
      uuid: teacher_profile.uuid,
      designation: teacher_profile.designation,
      subject: teacher_profile.subject,
      school: teacher_profile.school,
      program_manager: teacher_profile.program_manager,
      avg_rating: teacher_profile.avg_rating,
      user_profile: render_one(teacher_profile.user_profile, UserProfileView, "user_profile.json")
    }
  end

  def render("teacher_profile_with_user_profile.json", %{teacher_profile: teacher_profile}) do
    %{
      id: teacher_profile.id,
      user_profile_id: teacher_profile.user_profile_id,
      teacher_id: teacher_profile.teacher_id,
      uuid: teacher_profile.uuid,
      designation: teacher_profile.designation,
      subject: teacher_profile.subject,
      school: teacher_profile.school,
      program_manager: teacher_profile.program_manager,
      avg_rating: teacher_profile.avg_rating,
      user_profile: render_one(teacher_profile.user_profile, UserProfileView, "user_profile.json")
    }
  end
end
