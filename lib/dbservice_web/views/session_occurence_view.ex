defmodule DbserviceWeb.SessionOccurenceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SessionOccurenceView
  alias DbserviceWeb.UserView
  alias Dbservice.Repo

  def render("index.json", %{session_occurence: session_occurence}) do
    render_many(session_occurence, SessionOccurenceView, "session_occurence.json")
  end

  def render("show.json", %{session_occurence: session_occurence}) do
    render_one(session_occurence, SessionOccurenceView, "session_occurence.json")
  end

  def render("session_occurence.json", %{session_occurence: session_occurence}) do
    %{
      id: session_occurence.id,
      start_time: session_occurence.start_time,
      end_time: session_occurence.end_time,
      session_fk: session_occurence.session_fk,
      session_id: session_occurence.session_id,
      inserted_at: session_occurence.inserted_at,
      updated_at: session_occurence.updated_at
    }
  end

  def render("session_occurence_with_users.json", %{session_occurence: session_occurence}) do
    session_occurence = session_occurence |> Repo.preload(:users)

    %{
      id: session_occurence.id,
      start_time: session_occurence.start_time,
      end_time: session_occurence.end_time,
      session_fk: session_occurence.session_fk,
      session_id: session_occurence.session_id,
      users: render_many(session_occurence.users, UserView, "user.json")
    }
  end
end
