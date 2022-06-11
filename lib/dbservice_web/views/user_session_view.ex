defmodule DbserviceWeb.UserSessionView do
  use DbserviceWeb, :view
  alias DbserviceWeb.UserSessionView

  def render("index.json", %{user_session: user_session}) do
    %{data: render_many(user_session, UserSessionView, "user_session.json")}
  end

  def render("show.json", %{user_session: user_session}) do
    %{data: render_one(user_session, UserSessionView, "user_session.json")}
  end

  def render("user_session.json", %{user_session: user_session}) do
    %{
      id: user_session.id,
      start_time: user_session.start_time,
      end_time: user_session.end_time,
      user_id: user_session.user_id,
      session_occurence_id: user_session.session_occurence_id
    }
  end
end
