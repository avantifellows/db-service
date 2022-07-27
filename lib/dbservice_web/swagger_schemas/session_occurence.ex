defmodule DbserviceWeb.SwaggerSchema.SessionOccurence do
  @moduledoc false

  use PhoenixSwagger

  def session_occurence do
    %{
      SessionOccurence:
        swagger_schema do
          title("SessionOccurence")
          description("A session occurence for a session")

          properties do
            session_id(:integer, "Session ID")
            start_time(:timestamp, "Session occurence start time")
            end_time(:timestamp, "Session occurence finish time")
          end

          example(%{
            session_id: 1,
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z"
          })
        end
    }
  end

  def session_occurences do
    %{
      SessionOccurences:
        swagger_schema do
          title("SessionOccurences")
          description("All the session occurences ")
          type(:array)
          items(Schema.ref(:SessionOccurence))
        end
    }
  end

  def session_occurence_with_user do
    %{
      SessionOccurenceWithUser:
        swagger_schema do
          title("SessionOccurenceWithUser")
          description("A single session occurence with user details")

          properties do
            session_id(:integer, "Session ID")
            start_time(:timestamp, "Session occurence start time")
            end_time(:timestamp, "Session occurence finish time")
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
