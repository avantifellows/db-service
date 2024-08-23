defmodule DbserviceWeb.SessionOccurrenceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SessionOccurrenceView
  alias DbserviceWeb.UserView
  alias DbserviceWeb.SessionView
  alias Dbservice.Repo

  def render("index.json", %{session_occurrence: session_occurrence}) do
    render_many(session_occurrence, SessionOccurrenceView, "session_occurrence.json")
  end

  def render("show.json", %{session_occurrence: session_occurrence}) do
    render_one(session_occurrence, SessionOccurrenceView, "session_occurrence.json")
  end

  def render("session_occurrence.json", %{session_occurrence: session_occurrence}) do
    session_occurrence = session_occurrence |> Repo.preload(:session)

    %{
      id: session_occurrence.id,
      start_time: session_occurrence.start_time,
      end_time: session_occurrence.end_time,
      session_fk: session_occurrence.session_fk,
      session_id: session_occurrence.session_id,
      inserted_at: session_occurrence.inserted_at,
      updated_at: session_occurrence.updated_at,
      session: render_one(session_occurrence.session, SessionView, "session.json")
    }
  end

  def render("session_occurrence_with_users.json", %{session_occurrence: session_occurrence}) do
    session_occurrence = session_occurrence |> Repo.preload(:users)

    %{
      id: session_occurrence.id,
      start_time: session_occurrence.start_time,
      end_time: session_occurrence.end_time,
      session_fk: session_occurrence.session_fk,
      session_id: session_occurrence.session_id,
      users: render_many(session_occurrence.users, UserView, "user.json")
    }
  end
end
