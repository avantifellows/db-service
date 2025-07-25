defmodule DbserviceWeb.UserSessionJSON do
  def index(%{user_session: user_session}) do
    for(us <- user_session, do: render(us))
  end

  def show(%{user_session: user_session}) do
    render(user_session)
  end

  def render(user_session) do
    %{
      id: user_session.id,
      timestamp: user_session.timestamp,
      session_id: user_session.session_id,
      session_occurrence_id: user_session.session_occurrence_id,
      data: user_session.data,
      user_id: user_session.user_id,
      user_activity_type: user_session.user_activity_type
    }
  end
end
