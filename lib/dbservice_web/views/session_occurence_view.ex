defmodule DbserviceWeb.SessionOccurenceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SessionOccurenceView

  def render("index.json", %{session_occurence: session_occurence}) do
    %{data: render_many(session_occurence, SessionOccurenceView, "session_occurence.json")}
  end

  def render("show.json", %{session_occurence: session_occurence}) do
    %{data: render_one(session_occurence, SessionOccurenceView, "session_occurence.json")}
  end

  def render("session_occurence.json", %{session_occurence: session_occurence}) do
    %{
      id: session_occurence.id,
      start_time: session_occurence.start_time,
      end_time: session_occurence.end_time
    }
  end
end
