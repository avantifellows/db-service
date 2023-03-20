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
            session_occurrence_id(:integer, "The id of the session occurrence")
            is_user_valid(:boolean, "Signifies whether the user exist or not")
          end

          example(%{
            start_time: "2022-02-02T11:00:00Z",
            end_time: "2022-02-02T11:30:00Z",
            data: %{
              "substitute-teacher-name" => "Ms. Poonam"
            },
            is_user_valid: true,
            session_occurrence_id: 2
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
