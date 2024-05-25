defmodule DbserviceWeb.UserSessionView do
  use DbserviceWeb, :view
  alias DbserviceWeb.UserSessionView

  def render("index.json", %{user_session: user_session}) do
    render_many(user_session, UserSessionView, "user_session.json")
  end

  def render("show.json", %{user_session: user_session}) do
    render_one(user_session, UserSessionView, "user_session.json")
  end

  def render("user_session.json", %{user_session: user_session}) do
    %{
      id: user_session.id,
      timestamp: user_session.timestamp,
      session_id: user_session.session_id,
      data: user_session.data,
      user_id: user_session.user_id,
      user_activity_type: user_session.user_activity_type
    }
  end
end
