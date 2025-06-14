defmodule DbserviceWeb.SessionScheduleJSON do
  def index(%{session_schedule: session_schedule}) do
    %{data: for(ss <- session_schedule, do: data(ss))}
  end

  def show(%{session_schedule: session_schedule}) do
    %{data: data(session_schedule)}
  end

  def data(session_schedule) do
    %{
      id: session_schedule.id,
      day_of_week: session_schedule.day_of_week,
      start_time: session_schedule.start_time,
      end_time: session_schedule.end_time,
      session_id: session_schedule.session_id,
      inserted_at: session_schedule.inserted_at,
      updated_at: session_schedule.updated_at
    }
  end
end
