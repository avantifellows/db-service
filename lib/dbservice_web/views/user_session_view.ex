defmodule DbserviceWeb.UserSessionView do
  use DbserviceWeb, :view

  def render("index.json", %{user_session: user_sessions}) do
    Enum.map(user_sessions, &user_session_json/1)
  end

  def render("show.json", %{user_session: user_session}) do
    user_session_json(user_session)
  end

  def user_session_json(%{id: id, timestamp: timestamp, session_id: session_id, session_occurrence_id: session_occurrence_id, data: data, user_id: user_id, user_activity_type: user_activity_type}) do
    %{
      id: id,
      timestamp: timestamp,
      session_id: session_id,
      session_occurrence_id: session_occurrence_id,
      data: data,
      user_id: user_id,
      user_activity_type: user_activity_type
    }
  end
end
