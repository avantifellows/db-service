defmodule DbserviceWeb.SwaggerSchema.StudentProfile do
  @moduledoc false

  use PhoenixSwagger

  def student_profile do
    %{
      StudentProfile:
        swagger_schema do
          title("Student Profile")
          description("A student's profile in the application")

          properties do
            student_id(:string, "Student ID")
            took_test_atleast_once(:boolean, "Has the student taken a test at least once")

            took_class_atleast_once(
              :boolean,
              "Has the student participated in a class at least once"
            )

            total_number_of_tests(:integer, "Total number of tests")
            total_number_of_live_classes(:integer, "Total number of live classes")

            attendance_in_classes_current_year(
              :array,
              "Attendance in classes for each month this year"
            )

            classes_activity_cohort(:string, "Classes activity cohort")

            attendance_in_tests_current_year(
              :array,
              "Attendance in tests for each month this year"
            )

            tests_activity_cohort(:string, "Tests activity cohort")
            performance_trend_in_fst(:string, "Performance trend in FST")
            max_batch_score_in_latest_test(:integer, "Max batch score in latest test")
            average_batch_score_in_latest_test(:decimal, "Average batch score in latest test")

            tests_number_of_correct_questions(
              :integer,
              "Total Number of correct questions in tests"
            )

            tests_number_of_wrong_questions(:integer, "Total Number of wrong questions in tests")

            tests_number_of_skipped_questions(
              :integer,
              "Total Number of skipped questions in tests"
            )

            user_profile_id(:integer, "User profile ID associated with the student's profile")

            student_fk(
              :integer,
              "Student foreign key ID associated with the student's profile"
            )
          end

          example(%{
            student_id: "120180101057",
            took_test_atleast_once: true,
            took_class_atleast_once: true,
            total_number_of_tests: 20,
            total_number_of_live_classes: 50,
            attendance_in_classes_current_year: [
              89.0,
              90.2,
              20.3,
              35.7,
              42.1,
              66.4,
              88.9,
              91.2,
              77.3,
              54.6,
              33.8,
              10.1
            ],
            classes_activity_cohort: "Cohort A",
            attendance_in_tests_current_year: [
              89.0,
              90.2,
              20.3,
              35.7,
              42.1,
              66.4,
              88.9,
              91.2,
              77.3,
              54.6,
              33.8,
              10.1
            ],
            tests_activity_cohort: "Cohort B",
            performance_trend_in_fst: "Improving",
            max_batch_score_in_latest_test: 95,
            average_batch_score_in_latest_test: 88.5,
            tests_number_of_correct_questions: 75,
            tests_number_of_wrong_questions: 10,
            tests_number_of_skipped_questions: 15,
            user_profile_id: 3,
            student_fk: 2
          })
        end
    }
  end

  def student_profiles do
    %{
      StudentProfiles:
        swagger_schema do
          title("Student Profiles")
          description("All student profiles in the application")
          type(:array)
          items(Schema.ref(:StudentProfile))
        end
    }
  end

  def student_profile_setup do
    %{
      StudentProfileSetup:
        swagger_schema do
          title("StudentProfile Setup")
          description("A student's profile being setup with user profile")

          properties do
            student_id(:string, "Student ID")
            took_test_atleast_once(:boolean, "Has the student taken a test at least once")

            took_class_atleast_once(
              :boolean,
              "Has the student participated in a class at least once"
            )

            total_number_of_tests(:integer, "Total number of tests")
            total_number_of_live_classes(:integer, "Total number of live classes")

            attendance_in_classes_current_year(
              :array,
              "Attendance in classes for each month this year"
            )

            classes_activity_cohort(:string, "Classes activity cohort")

            attendance_in_tests_current_year(
              :array,
              "Attendance in tests for each month this year"
            )

            tests_activity_cohort(:string, "Tests activity cohort")
            performance_trend_in_fst(:string, "Performance trend in FST")
            max_batch_score_in_latest_test(:integer, "Max batch score in latest test")
            average_batch_score_in_latest_test(:decimal, "Average batch score in latest test")

            tests_number_of_correct_questions(
              :integer,
              "Total Number of correct questions in tests"
            )

            tests_number_of_wrong_questions(:integer, "Total Number of wrong questions in tests")

            tests_number_of_skipped_questions(
              :integer,
              "Total Number of skipped questions in tests"
            )

            logged_in_atleast_once(:boolean, "Has user logged in atleast once?")
            latest_session_accessed(:string, "Name of the latest session accessed")
          end

          example(%{
            student_id: "120180101057",
            took_test_atleast_once: true,
            took_class_atleast_once: true,
            total_number_of_tests: 20,
            total_number_of_live_classes: 50,
            attendance_in_classes_current_year: [
              89.0,
              90.2,
              20.3,
              35.7,
              42.1,
              66.4,
              88.9,
              91.2,
              77.3,
              54.6,
              33.8,
              10.1
            ],
            classes_activity_cohort: "Cohort A",
            attendance_in_tests_current_year: [
              89.0,
              90.2,
              20.3,
              35.7,
              42.1,
              66.4,
              88.9,
              91.2,
              77.3,
              54.6,
              33.8,
              10.1
            ],
            tests_activity_cohort: "Cohort B",
            performance_trend_in_fst: "Improving",
            max_batch_score_in_latest_test: 95,
            average_batch_score_in_latest_test: 88.5,
            tests_number_of_correct_questions: 75,
            tests_number_of_wrong_questions: 10,
            tests_number_of_skipped_questions: 15,
            logged_in_atleast_once: true,
            latest_session_accessed: "LiveClass_10"
          })
        end
    }
  end

  def student_profile_with_user_profile do
    %{
      StudentProfileWithUserProfile:
        swagger_schema do
          title("StudentProfile With UserProfile")
          description("A student's profile with associated user profile")

          properties do
            student_id(:string, "Student ID")
            took_test_atleast_once(:boolean, "Has the student taken a test at least once")

            took_class_atleast_once(
              :boolean,
              "Has the student participated in a class at least once"
            )

            took_test_atleast_once(:boolean, "Has the student taken a test at least once")

            took_class_atleast_once(
              :boolean,
              "Has the student participated in a class at least once"
            )

            total_number_of_tests(:integer, "Total number of tests")
            total_number_of_live_classes(:integer, "Total number of live classes")

            attendance_in_classes_current_year(
              :array,
              "Attendance in classes for each month this year"
            )

            classes_activity_cohort(:string, "Classes activity cohort")

            attendance_in_tests_current_year(
              :array,
              "Attendance in tests for each month this year"
            )

            tests_activity_cohort(:string, "Tests activity cohort")
            performance_trend_in_fst(:string, "Performance trend in FST")
            max_batch_score_in_latest_test(:integer, "Max batch score in latest test")
            average_batch_score_in_latest_test(:decimal, "Average batch score in latest test")

            tests_number_of_correct_questions(
              :integer,
              "Total Number of correct questions in tests"
            )

            tests_number_of_wrong_questions(:integer, "Total Number of wrong questions in tests")

            tests_number_of_skipped_questions(
              :integer,
              "Total Number of skipped questions in tests"
            )

            student_fk(
              :integer,
              "Student foreign key ID associated with the student's profile"
            )

            user_profile(:map, "User Profile details associated with the student")
          end

          example(%{
            student_id: "120180101057",
            took_test_atleast_once: true,
            took_class_atleast_once: true,
            total_number_of_tests: 20,
            total_number_of_live_classes: 50,
            attendance_in_classes_current_year: [
              89.0,
              90.2,
              20.3,
              35.7,
              42.1,
              66.4,
              88.9,
              91.2,
              77.3,
              54.6,
              33.8,
              10.1
            ],
            classes_activity_cohort: "Cohort A",
            attendance_in_tests_current_year: [
              89.0,
              90.2,
              20.3,
              35.7,
              42.1,
              66.4,
              88.9,
              91.2,
              77.3,
              54.6,
              33.8,
              10.1
            ],
            tests_activity_cohort: "Cohort B",
            performance_trend_in_fst: "Improving",
            max_batch_score_in_latest_test: 95,
            average_batch_score_in_latest_test: 88.5,
            tests_number_of_correct_questions: 75,
            tests_number_of_wrong_questions: 10,
            tests_number_of_skipped_questions: 15,
            student_fk: 1,
            user_profile: %{
              user_id: 1,
              logged_in_atleast_once: true,
              latest_session_accessed: "LiveClass_10"
            }
          })
        end
    }
  end
end
