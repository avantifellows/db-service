defmodule DbserviceWeb.UserProfileView do
  use DbserviceWeb, :view
  alias DbserviceWeb.UserProfileView

  def render("index.json", %{user_profile: user_profile}) do
    render_many(user_profile, UserProfileView, "user_profile.json")
  end

  def render("show.json", %{user_profile: user_profile}) do
    render_one(user_profile, UserProfileView, "user_profile.json")
  end

  def render("user_profile.json", %{user_profile: user_profile}) do
    %{
      id: user_profile.id,
      user_id: user_profile.user_id,
      full_name: user_profile.full_name,
      email: user_profile.email,
      date_of_birth: user_profile.date_of_birth,
      gender: user_profile.gender,
      role: user_profile.role,
      state: user_profile.state,
      country: user_profile.country,
      current_grade: user_profile.current_grade,
      current_program: user_profile.current_program,
      current_batch: user_profile.current_batch,
      logged_in_atleast_once: user_profile.logged_in_atleast_once,
      first_session_accessed: user_profile.first_session_accessed,
      latest_session_accessed: user_profile.latest_session_accessed
    }
  end
end
