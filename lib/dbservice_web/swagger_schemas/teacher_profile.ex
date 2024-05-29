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
            teacher_id(:string, "Teacher ID associated with the teacher's profile")
            school(:string, "School where the teacher works")
            program_manager(:string, "Program manager for the teacher")
            avg_rating(:decimal, "Average rating of the teacher")
            user_profile_id(:integer, "User profile ID associated with the teacher's profile")

            teacher_fk(
              :integer,
              "Teacher foreign key ID associated with the teacher's profile"
            )
          end

          example(%{
            teacher_id: "20202",
            school: "XYZ High School",
            program_manager: "John Doe",
            avg_rating: 4.5,
            user_profile_id: 1,
            teacher_fk: 3
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
            school(:string, "School where the teacher works")
            program_manager(:string, "Program manager for the teacher")
            avg_rating(:decimal, "Average rating of the teacher")
            teacher_id(:string, "Teacher ID associated with the teacher's profile")

            current_grade(:string, "Current Grade")
            current_program(:string, "Current Program")
            current_batch(:string, "Current Batch")
            logged_in_atleast_once(:boolean, "Has user logged in atleast once?")
            latest_session_accessed(:string, "Name of the latest session accessed")
          end

          example(%{
            school: "XYZ High School",
            program_manager: "John Doe",
            avg_rating: 4.5,
            teacher_id: "20202",
            current_grade: "11",
            current_program: "HaryanaStudents",
            current_batch: "Photon",
            logged_in_atleast_once: false,
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
            school(:string, "School where the teacher works")
            program_manager(:string, "Program manager for the teacher")
            avg_rating(:decimal, "Average rating of the teacher")
            teacher_id(:string, "Teacher ID associated with the teacher's profile")
            user_profile(:map, "User Profile details associated with the teacher")

            teacher_fk(
              :integer,
              "Teacher foreign key ID associated with the student's profile"
            )
          end

          example(%{
            school: "XYZ High School",
            program_manager: "John Doe",
            avg_rating: 4.5,
            teacher_id: "30",
            teacher_fk: 2,
            user_profile: %{
              user_id: 2,
              current_grade: "11",
              current_program: "HaryanaStudents",
              current_batch: "Photon",
              logged_in_atleast_once: false,
              latest_session_accessed: "LiveClass_10"
            }
          })
        end
    }
  end
end
