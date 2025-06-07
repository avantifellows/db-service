defmodule DbserviceWeb.SessionOccurrenceJSON do
  alias DbserviceWeb.SessionJSON

  def index(%{session_occurrence: session_occurrence}) do
    %{data: for(so <- session_occurrence, do: data(so))}
  end

  def show(%{session_occurrence: session_occurrence}) do
    %{data: data(session_occurrence)}
  end

  def data(session_occurrence) do
    session_occurrence = session_occurrence |> Dbservice.Repo.preload(:session)

    %{
      id: session_occurrence.id,
      start_time: session_occurrence.start_time,
      end_time: session_occurrence.end_time,
      session_fk: session_occurrence.session_fk,
      session_id: session_occurrence.session_id,
      inserted_at: session_occurrence.inserted_at,
      updated_at: session_occurrence.updated_at,
      session:
        if(session_occurrence.session,
          do: SessionJSON.data(session_occurrence.session),
          else: nil
        )
    }
  end

  def session_occurrence_with_users(%{session_occurrence: session_occurrence}) do
    session_occurrence = session_occurrence |> Dbservice.Repo.preload(:users)

    %{
      data: %{
        id: session_occurrence.id,
        start_time: session_occurrence.start_time,
        end_time: session_occurrence.end_time,
        session_fk: session_occurrence.session_fk,
        session_id: session_occurrence.session_id,
        users: for(u <- session_occurrence.users, do: DbserviceWeb.UserJSON.data(u))
      }
    }
  end
end
