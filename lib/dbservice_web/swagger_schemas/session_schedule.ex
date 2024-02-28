defmodule DbserviceWeb.SwaggerSchema.SessionSchedule do
  @moduledoc false

  use PhoenixSwagger

  def session_schedule do
    %{
      SessionSchedule:
        swagger_schema do
          title("SessionSchedule")
          description("Schedule of a session in the application")

          properties do
            session_id(:integer, "Session id associated with the session schedule")
            day_of_week(:integer, "Grade id associated with the topic")
            start_time(:time, "Session's start time")
            end_time(:time, "Session's end time")
            batch_id(:integer, "Batch id associated with the session schedule")
          end

          example(%{
            session_id: 1,
            day_of_week: "Monday",
            start_time: "11:00",
            end_time: "11:30",
            batch_id: 1
          })
        end
    }
  end

  def session_schedules do
    %{
      SessionSchedules:
        swagger_schema do
          title("SessionSchedules")
          description("All session schedules in the application")
          type(:array)
          items(Schema.ref(:SessionSchedule))
        end
    }
  end
end
