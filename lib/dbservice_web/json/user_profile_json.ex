defmodule DbserviceWeb.UserProfileJSON do
  def index(%{user_profile: user_profile}) do
    for(up <- user_profile, do: render(up))
  end

  def show(%{user_profile: user_profile}) do
    render(user_profile)
  end

  def render(user_profile) do
    %{
      id: user_profile.id,
      user_id: user_profile.user_id,
      logged_in_atleast_once: user_profile.logged_in_atleast_once,
      latest_session_accessed: user_profile.latest_session_accessed
    }
  end
end
