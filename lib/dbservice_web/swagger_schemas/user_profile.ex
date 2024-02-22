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
            full_name(:string, "Full name")
            user_id(:integer, "Corresponding user ID of the user")
            email(:string, "Email")
            gender(:string, "Gender")
            date_of_birth(:date, "Date of Birth")
            role(:string, "User role")
            state(:string, "State")
            country(:string, "Country")
            current_grade(:string, "Current Grade")
            current_program(:string, "Current Program")
            current_batch(:string, "Current Batch")
            logged_in_atleast_once(:boolean, "Has user logged in atleast once?")
            first_session_accessed(:string, "Name of the first session accessed")
            latest_session_accessed(:string, "Name of the latest session accessed")
          end

          example(%{
            full_name: "Rahul Sharma",
            user_id: 10,
            email: "rahul.sharma@example.com",
            gender: "Male",
            date_of_birth: "2003-08-22",
            role: "student",
            state: "Maharashtra",
            country: "India",
            current_grade: "11",
            current_program: "HaryanaStudents",
            current_batch: "Photon",
            logged_in_atleast_once: true,
            first_session_accessed: "DemoTest_32",
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
