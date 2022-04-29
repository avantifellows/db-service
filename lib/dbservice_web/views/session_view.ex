defmodule DbserviceWeb.SessionView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SessionView

  def render("index.json", %{session: session}) do
    %{data: render_many(session, SessionView, "session.json")}
  end

  def render("show.json", %{session: session}) do
    %{data: render_one(session, SessionView, "session.json")}
  end

  def render("session.json", %{session: session}) do
    %{
      id: session.id,
      name: session.name,
      type: session.type,
      type_uid: session.type_uid,
      portal_link: session.portal_link,
      start_time: session.start_time,
      end_time: session.end_time,
      repeat_type: session.repeat_type,
      repeat_till_date: session.repeat_till_date,
      meta_data: session.meta_data
    }
  end
end
