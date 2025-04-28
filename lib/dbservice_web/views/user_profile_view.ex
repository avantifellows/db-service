defmodule DbserviceWeb.UserProfileView do
  use DbserviceWeb, :view

  def render("index.json", %{user_profile: user_profiles}) do
    Enum.map(user_profiles, &user_profile_json/1)
  end

  def render("show.json", %{user_profile: user_profile}) do
    user_profile_json(user_profile)
  end

  def user_profile_json(%{__meta__: _meta} = user_profile) do
    %{
      id: user_profile.id,
      user_id: user_profile.user_id,
      current_grade: user_profile.current_grade,
      current_program: user_profile.current_program,
      current_batch: user_profile.current_batch,
      logged_in_atleast_once: user_profile.logged_in_atleast_once,
      latest_session_accessed: user_profile.latest_session_accessed
    }
  end
end
