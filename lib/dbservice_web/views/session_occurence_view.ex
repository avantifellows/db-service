defmodule DbserviceWeb.SessionOccurrenceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.UserView
  alias DbserviceWeb.SessionView
  alias Dbservice.Repo

  def render("index.json", %{session_occurrences: session_occurrences}) do
    Enum.map(session_occurrences, &session_occurrence_json/1)
  end

  def render("show.json", %{session_occurrence: session_occurrence}) do
    session_occurrence_json(session_occurrence)
  end
  def render("session_occurrence_with_users.json", %{session_occurrence: session_occurrence}) do
    session_occurrence = session_occurrence |> Repo.preload(:users)

    %{
      id: session_occurrence.id,
      start_time: session_occurrence.start_time,
      end_time: session_occurrence.end_time,
      session_fk: session_occurrence.session_fk,
      session_id: session_occurrence.session_id,
      users: Enum.map(session_occurrence.users, &UserView.user_json/1)
    }
  end

  def session_occurrence_json(%{__meta__: _meta} = session_occurrence) do
    session_occurrence = session_occurrence |> Repo.preload(:session)

    %{
      id: session_occurrence.id,
      start_time: session_occurrence.start_time,
      end_time: session_occurrence.end_time,
      session_fk: session_occurrence.session_fk,
      session_id: session_occurrence.session_id,
      inserted_at: session_occurrence.inserted_at,
      updated_at: session_occurrence.updated_at,
      session: SessionView.session_json(session_occurrence.session)
    }
  end

end
