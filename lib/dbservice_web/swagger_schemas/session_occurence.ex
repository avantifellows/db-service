defmodule DbserviceWeb.SwaggerSchema.SessionOccurrence do
  @moduledoc false

  use PhoenixSwagger

  def session_occurrence do
    %{
      SessionOccurence:
        swagger_schema do
          title("SessionOccurrence")
          description("A session occurrence for a session")

          properties do
            session_id(:integer, "Session ID")
            start_time(:timestamp, "Session occurrence start time")
            end_time(:timestamp, "Session occurrence finish time")
          end

          example(%{
            session_id: 1,
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z"
          })
        end
    }
  end

  def session_occurrences do
    %{
      SessionOccurences:
        swagger_schema do
          title("SessionOccurrences")
          description("All the session occurrences ")
          type(:array)
          items(Schema.ref(:SessionOccurence))
        end
    }
  end

  def session_occurrence_with_user do
    %{
      SessionOccurenceWithUser:
        swagger_schema do
          title("SessionOccurrenceWithUser")
          description("A single session occurrence with user details")

          properties do
            session_id(:integer, "Session ID")
            start_time(:timestamp, "Session occurrence start time")
            end_time(:timestamp, "Session occurrence finish time")
          end

          example(%{
            session_id: 1,
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z"
          })
        end
    }
  end
end
