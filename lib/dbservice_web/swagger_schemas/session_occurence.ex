defmodule DbserviceWeb.SwaggerSchema.SessionOccurence do
  @moduledoc false

  use PhoenixSwagger

  def session_occurrence do
    %{
      SessionOccurrence:
        swagger_schema do
          title("SessionOccurrence")
          description("A session occurrence for a session")

          properties do
            session_id(:string, "ID of the session")
            start_time(:timestamp, "Session occurrence start time")
            end_time(:timestamp, "Session occurrence finish time")
            session_fk(:integer, "The primary key for session's table")
            inserted_at(:timestamp, "Timestamp when the record was created")
            updated_at(:timestamp, "Timestamp when the record was last updated")
          end

          example(%{
            session_id: "DelhiStudents_B01_44725_unv-nkyh-hnb",
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z",
            session_fk: 1
          })
        end
    }
  end

  def session_occurrences do
    %{
      SessionOccurrences:
        swagger_schema do
          title("SessionOccurrences")
          description("All the session occurrences ")
          type(:array)
          items(Schema.ref(:SessionOccurrence))
        end
    }
  end

  def session_occurrence_with_user do
    %{
      SessionOccurrenceWithUser:
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
