defmodule DbserviceWeb.SessionScheduleView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SessionView
  alias Dbservice.Repo

  def render("index.json", %{session_schedule: session_schedule}) do
    Enum.map(session_schedule, &session_schedule_json/1)
  end

  def render("show.json", %{session_schedule: session_schedule}) do
    session_schedule_json(session_schedule)
  end

  def session_schedule_json(%{__meta__: _, session: session} = session_schedule) do
    session_schedule = Repo.preload(session_schedule, :session)

    %{
      id: session_schedule.id,
      session_id: session_schedule.session_id,
      day_of_week: session_schedule.day_of_week,
      start_time: session_schedule.start_time,
      end_time: session_schedule.end_time,
      batch_id: session_schedule.batch_id,
      session: SessionView.session_json(session)
    }
 end
end
