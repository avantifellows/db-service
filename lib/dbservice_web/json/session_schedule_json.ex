defmodule DbserviceWeb.SessionScheduleJSON do
  def index(%{session_schedule: session_schedule}) do
    for(ss <- session_schedule, do: render(ss))
  end

  def show(%{session_schedule: session_schedule}) do
    render(session_schedule)
  end

  def render(session_schedule) do
    session_schedule = Repo.preload(session_schedule, :session)
    %{
      id: session_schedule.id,
      day_of_week: session_schedule.day_of_week,
      start_time: session_schedule.start_time,
      end_time: session_schedule.end_time,
      session_id: session_schedule.session_id,
      session: if(session_schedule.session,
        do: DbserviceWeb.SessionJSON.render(session_schedule.session),
        else: nil
      ),
      batch_id: session_schedule.batch_id,
    }
  end
end
