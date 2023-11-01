defmodule DbserviceWeb.SwaggerSchema.TeacherProfile do
  @moduledoc false

  use PhoenixSwagger

  def teacher_profile do
    %{
      TeacherProfile:
        swagger_schema do
          title("TeacherProfile")
          description("A teacher's profile in the application")

          properties do
            uuid(:string, "UUID of the teacher")
            designation(:string, "Designation of the teacher")
            subject(:string, "Subject taught by the teacher")
            school(:string, "School where the teacher works")
            program_manager(:string, "Program manager for the teacher")
            avg_rating(:decimal, "Average rating of the teacher")
            user_profile_id(:integer, "User profile ID associated with the teacher's profile")
            teacher_id(:integer, "Teacher ID associated with the teacher's profile")
          end

          example(%{
            uuid: "abc123",
            designation: "Math Teacher",
            subject: "Mathematics",
            school: "XYZ High School",
            program_manager: "John Doe",
            avg_rating: 4.5,
            user_profile_id: 1,
            teacher_id: 1
          })
        end
    }
  end

  def teacher_profiles do
    %{
      TeacherProfiles:
        swagger_schema do
          title("Teacher Profiles")
          description("All teacher profiles in the application")
          type(:array)
          items(Schema.ref(:TeacherProfile))
        end
    }
  end

  def teacher_profile_setup do
    %{
      TeacherProfileSetup:
        swagger_schema do
          title("TeacherProfile Setup")
          description("A teacher's profile with associated user profile being set up")

          properties do
            uuid(:string, "UUID of the teacher")
            designation(:string, "Designation of the teacher")
            subject(:string, "Subject taught by the teacher")
            school(:string, "School where the teacher works")
            program_manager(:string, "Program manager for the teacher")
            avg_rating(:decimal, "Average rating of the teacher")
            teacher_id(:integer, "Teacher ID associated with the teacher's profile")
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
            uuid: "abc123",
            designation: "Math Teacher",
            subject: "Mathematics",
            school: "XYZ High School",
            program_manager: "John Doe",
            avg_rating: 4.5,
            teacher_id: 1,
            full_name: "John Doe",
            user_id: 1,
            email: "john.doe@example.com",
            gender: "Male",
            date_of_birth: "1980-05-15",
            role: "teacher",
            state: "California",
            country: "USA",
            current_grade: "11",
            current_program: "HaryanaStudents",
            current_batch: "Photon",
            logged_in_atleast_once: false,
            first_session_accessed: "LiveClass_1",
            latest_session_accessed: "LiveClass_10"
          })
        end
    }
  end

  def teacher_profile_with_user_profile do
    %{
      TeacherProfileWithUserProfile:
        swagger_schema do
          title("TeacherProfile With UserProfile")
          description("A teacher's profile with associated user profile")

          properties do
            uuid(:string, "UUID of the teacher")
            designation(:string, "Designation of the teacher")
            subject(:string, "Subject taught by the teacher")
            school(:string, "School where the teacher works")
            program_manager(:string, "Program manager for the teacher")
            avg_rating(:decimal, "Average rating of the teacher")
            teacher_id(:integer, "Teacher ID associated with the teacher's profile")
            user_profile(:map, "User Profile details associated with the teacher")
          end

          example(%{
            uuid: "abc123",
            designation: "Math Teacher",
            subject: "Mathematics",
            school: "XYZ High School",
            program_manager: "John Doe",
            avg_rating: 4.5,
            teacher_id: 1,
            user_profile: %{
              full_name: "John Doe",
              user_id: 1,
              email: "john.doe@example.com",
              gender: "Male",
              date_of_birth: "1980-05-15",
              role: "teacher",
              state: "California",
              country: "USA",
              current_grade: "11",
              current_program: "HaryanaStudents",
              current_batch: "Photon",
              logged_in_atleast_once: false,
              first_session_accessed: "LiveClass_1",
              latest_session_accessed: "LiveClass_10"
            }
          })
        end
    }
  end
end
