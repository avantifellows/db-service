defmodule DbserviceWeb.SessionScheduleView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SessionScheduleView
  alias DbserviceWeb.SessionView
  alias Dbservice.Repo

  def render("index.json", %{session_schedule: session_schedule}) do
    render_many(session_schedule, SessionScheduleView, "session_schedule.json")
  end

  def render("show.json", %{session_schedule: session_schedule}) do
    render_one(session_schedule, SessionScheduleView, "session_schedule.json")
  end

  def render("session_schedule.json", %{session_schedule: session_schedule}) do
    session_schedule = Repo.preload(session_schedule, :session)

    %{
      id: session_schedule.id,
      session_id: session_schedule.session_id,
      day_of_week: session_schedule.day_of_week,
      start_time: session_schedule.start_time,
      end_time: session_schedule.end_time,
      batch_id: session_schedule.batch_id,
      session: render_one(session_schedule.session, SessionView, "session.json")
    }
  end
end
