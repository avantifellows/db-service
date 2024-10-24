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
      logged_in_atleast_once: user_profile.logged_in_atleast_once,
      latest_session_accessed: user_profile.latest_session_accessed
    }
  end
end
