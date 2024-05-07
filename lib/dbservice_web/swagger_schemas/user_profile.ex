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
            current_grade(:string, "Current Grade")
            current_program(:string, "Current Program")
            current_batch(:string, "Current Batch")
            logged_in_atleast_once(:boolean, "Has user logged in atleast once?")
            latest_session_accessed(:string, "Name of the latest session accessed")
          end

          example(%{
            user_id: 10,
            current_grade: "11",
            current_program: "HaryanaStudents",
            current_batch: "Photon",
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
