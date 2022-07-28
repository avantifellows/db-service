defmodule DbserviceWeb.SwaggerSchema.UserSession do
  @moduledoc false

  use PhoenixSwagger

  def user_session do
    %{
      UserSession:
        swagger_schema do
          title("UserSession")
          description("A mapping between user and sesssion-occurence")

          properties do
            start_time(:timestamp, "User session start time")
            end_time(:timestamp, "User session end time")
            data(:map, "Additional data for user session")
            user_id(:integer, "The id of the user")
            session_occurence_id(:integer, "The id of the session occurence")
          end

          example(%{
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z",
            data: %{
              "substitute-teacher-name" => "Ms. Poonam"
            },
            user_id: 1,
            session_occurence_id: 2
          })
        end
    }
  end

  def user_sessions do
    %{
      UserSessions:
        swagger_schema do
          title("UserSessions")
          description("All user and session occurence mappings")
          type(:array)
          items(Schema.ref(:UserSession))
        end
    }
  end
end
