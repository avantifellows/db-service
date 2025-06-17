defmodule DbserviceWeb.UserProfileJSON do
  def index(%{user_profile: user_profile}) do
    for(up <- user_profile, do: data(up))
  end

  def show(%{user_profile: user_profile}) do
    data(user_profile)
  end

  def data(user_profile) do
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
