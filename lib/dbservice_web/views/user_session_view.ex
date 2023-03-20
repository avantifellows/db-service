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
      start_time: user_session.start_time,
      end_time: user_session.end_time,
      session_occurrence_id: user_session.session_occurrence_id,
      data: user_session.data,
      is_user_valid: user_session.is_user_valid,
      user_id: user_session.user_id
    }
  end
end
