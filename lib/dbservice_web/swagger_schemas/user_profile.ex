defmodule DbserviceWeb.SwaggerSchema.UserProfile do
  @moduledoc false

  use PhoenixSwagger

  def user_profile do
    %{
      UserProfile:
        swagger_schema do
          title("User Profile")
          description("A user's profile in the application")

          properties do
            user_id(:integer, "Corresponding user ID of the user")
            logged_in_atleast_once(:boolean, "Has user logged in atleast once?")
            latest_session_accessed(:string, "Name of the latest session accessed")
          end

          example(%{
            user_id: 10,
            logged_in_atleast_once: true,
            latest_session_accessed: "LiveClass_10"
          })
        end
    }
  end

  def user_profiles do
    %{
      UserProfiles:
        swagger_schema do
          title("User Profiles")
          description("All user profiles in the application")
          type(:array)
          items(Schema.ref(:UserProfile))
        end
    }
  end
end
