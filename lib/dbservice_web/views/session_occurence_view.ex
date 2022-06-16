defmodule DbserviceWeb.SessionOccurenceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SessionOccurenceView
  alias DbserviceWeb.UserView

  def render("index.json", %{session_occurence: session_occurence}) do
    %{data: render_many(session_occurence, SessionOccurenceView, "session_occurence.json")}
  end

  def render("show.json", %{session_occurence: session_occurence}) do
    %{
      data:
        render_one(session_occurence, SessionOccurenceView, "session_occurence_with_users.json")
    }
  end

  def render("session_occurence.json", %{session_occurence: session_occurence}) do
    %{
      id: session_occurence.id,
      start_time: session_occurence.start_time,
      end_time: session_occurence.end_time
    }
  end

  def render("session_occurence_with_users.json", %{session_occurence: session_occurence}) do
    %{
      id: session_occurence.id,
      start_time: session_occurence.start_time,
      end_time: session_occurence.end_time,
      users: render_many(session_occurence.users, UserView, "user.json")
    }
  end
end
