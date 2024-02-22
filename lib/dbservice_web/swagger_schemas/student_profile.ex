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
            father_education_level(:string, "Father's education level")
            father_profession(:string, "Father's profession")
            mother_education_level(:string, "Mother's education level")
            mother_profession(:string, "Mother's profession")
            category(:string, "Category")
            stream(:string, "Stream")
            physically_handicapped(:boolean, "Is student physically handicapped?")
            annual_family_income(:string, "Annual family income")
            has_internet_access(:string, "Has internet access")
            took_test_atleast_once(:boolean, "Has the student taken a test at least once")

            took_class_atleast_once(
              :boolean,
              "Has the student participated in a class at least once"
            )

            total_number_of_tests(:integer, "Total number of tests")
            total_number_of_live_classes(:integer, "Total number of live classes")
            attendance_in_classes_current_q1(:decimal, "Attendance in classes Q1")
            attendance_in_classes_current_q2(:decimal, "Attendance in classes Q2")
            attendance_in_classes_current_q3(:decimal, "Attendance in classes Q3")
            attendance_in_classes_current_year(:decimal, "Attendance in classes this year")
            classes_activity_cohort(:string, "Classes activity cohort")
            attendance_in_tests_current_q1(:decimal, "Attendance in tests Q1")
            attendance_in_tests_current_q2(:decimal, "Attendance in tests Q2")
            attendance_in_tests_current_q3(:decimal, "Attendance in tests Q3")
            attendance_in_tests_current_year(:decimal, "Attendance in tests this year")
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

            student_fkey_id(
              :integer,
              "Student foreign key ID associated with the student's profile"
            )
          end

          example(%{
            student_id: "120180101057",
            father_education_level: "Graduate",
            father_profession: "Engineer",
            mother_education_level: "Postgraduate",
            mother_profession: "Doctor",
            category: "General",
            stream: "Science",
            physically_handicapped: false,
            annual_family_income: "5LPA-10LPA",
            has_internet_access: "Yes",
            took_test_atleast_once: true,
            took_class_atleast_once: true,
            total_number_of_tests: 20,
            total_number_of_live_classes: 50,
            attendance_in_classes_current_q1: 85.5,
            attendance_in_classes_current_q2: 90.0,
            attendance_in_classes_current_q3: 92.5,
            attendance_in_classes_current_year: 89.0,
            classes_activity_cohort: "Cohort A",
            attendance_in_tests_current_q1: 80.0,
            attendance_in_tests_current_q2: 88.0,
            attendance_in_tests_current_q3: 90.5,
            attendance_in_tests_current_year: 86.2,
            tests_activity_cohort: "Cohort B",
            performance_trend_in_fst: "Improving",
            max_batch_score_in_latest_test: 95,
            average_batch_score_in_latest_test: 88.5,
            tests_number_of_correct_questions: 75,
            tests_number_of_wrong_questions: 10,
            tests_number_of_skipped_questions: 15,
            user_profile_id: 3,
            student_fkey_id: 2
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
            father_education_level(:string, "Father's education level")
            father_profession(:string, "Father's profession")
            mother_education_level(:string, "Mother's education level")
            mother_profession(:string, "Mother's profession")
            category(:string, "Category")
            stream(:string, "Stream")
            physically_handicapped(:boolean, "Is student physically handicapped?")
            annual_family_income(:string, "Annual family income")
            has_internet_access(:string, "Has internet access")
            took_test_atleast_once(:boolean, "Has the student taken a test at least once")

            took_class_atleast_once(
              :boolean,
              "Has the student participated in a class at least once"
            )

            total_number_of_tests(:integer, "Total number of tests")
            total_number_of_live_classes(:integer, "Total number of live classes")
            attendance_in_classes_current_q1(:decimal, "Attendance in classes Q1")
            attendance_in_classes_current_q2(:decimal, "Attendance in classes Q2")
            attendance_in_classes_current_q3(:decimal, "Attendance in classes Q3")
            attendance_in_classes_current_year(:decimal, "Attendance in classes this year")
            classes_activity_cohort(:string, "Classes activity cohort")
            attendance_in_tests_current_q1(:decimal, "Attendance in tests Q1")
            attendance_in_tests_current_q2(:decimal, "Attendance in tests Q2")
            attendance_in_tests_current_q3(:decimal, "Attendance in tests Q3")
            attendance_in_tests_current_year(:decimal, "Attendance in tests this year")
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

            student_fkey_id(
              :integer,
              "Student foreign key ID associated with the student's profile"
            )

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
            student_id: "120180101057",
            father_education_level: "Graduate",
            father_profession: "Engineer",
            mother_education_level: "Postgraduate",
            mother_profession: "Doctor",
            category: "General",
            stream: "Science",
            physically_handicapped: false,
            annual_family_income: "5LPA-10LPA",
            has_internet_access: "Yes",
            took_test_atleast_once: true,
            took_class_atleast_once: true,
            total_number_of_tests: 20,
            total_number_of_live_classes: 50,
            attendance_in_classes_current_q1: 85.5,
            attendance_in_classes_current_q2: 90.0,
            attendance_in_classes_current_q3: 92.5,
            attendance_in_classes_current_year: 89.0,
            classes_activity_cohort: "Cohort A",
            attendance_in_tests_current_q1: 80.0,
            attendance_in_tests_current_q2: 88.0,
            attendance_in_tests_current_q3: 90.5,
            attendance_in_tests_current_year: 86.2,
            tests_activity_cohort: "Cohort B",
            performance_trend_in_fst: "Improving",
            max_batch_score_in_latest_test: 95,
            average_batch_score_in_latest_test: 88.5,
            tests_number_of_correct_questions: 75,
            tests_number_of_wrong_questions: 10,
            tests_number_of_skipped_questions: 15,
            student_fkey_id: 1,
            full_name: "John Doe",
            user_id: 1,
            email: "john.doe@example.com",
            gender: "Male",
            date_of_birth: "2000-01-15",
            role: "student",
            state: "California",
            country: "USA",
            current_grade: "11",
            current_program: "Science",
            current_batch: "Batch A",
            logged_in_atleast_once: true,
            first_session_accessed: "DemoTest_1",
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
            father_education_level(:string, "Father's education level")
            father_profession(:string, "Father's profession")
            mother_education_level(:string, "Mother's education level")
            mother_profession(:string, "Mother's profession")
            category(:string, "Category")
            stream(:string, "Stream")
            physically_handicapped(:boolean, "Is student physically handicapped?")
            annual_family_income(:string, "Annual family income")
            has_internet_access(:string, "Has internet access")
            took_test_atleast_once(:boolean, "Has the student taken a test at least once")

            took_class_atleast_once(
              :boolean,
              "Has the student participated in a class at least once"
            )

            total_number_of_tests(:integer, "Total number of tests")
            total_number_of_live_classes(:integer, "Total number of live classes")
            attendance_in_classes_current_q1(:decimal, "Attendance in classes Q1")
            attendance_in_classes_current_q2(:decimal, "Attendance in classes Q2")
            attendance_in_classes_current_q3(:decimal, "Attendance in classes Q3")
            attendance_in_classes_current_year(:decimal, "Attendance in classes this year")
            classes_activity_cohort(:string, "Classes activity cohort")
            attendance_in_tests_current_q1(:decimal, "Attendance in tests Q1")
            attendance_in_tests_current_q2(:decimal, "Attendance in tests Q2")
            attendance_in_tests_current_q3(:decimal, "Attendance in tests Q3")
            attendance_in_tests_current_year(:decimal, "Attendance in tests this year")
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

            student_fkey_id(
              :integer,
              "Student foreign key ID associated with the student's profile"
            )

            user_profile(:map, "User Profile details associated with the student")
          end

          example(%{
            student_id: "120180101057",
            father_education_level: "Graduate",
            father_profession: "Engineer",
            mother_education_level: "Postgraduate",
            mother_profession: "Doctor",
            category: "General",
            stream: "Science",
            physically_handicapped: false,
            annual_family_income: "5LPA-10LPA",
            has_internet_access: "Yes",
            took_test_atleast_once: true,
            took_class_atleast_once: true,
            total_number_of_tests: 20,
            total_number_of_live_classes: 50,
            attendance_in_classes_current_q1: 85.5,
            attendance_in_classes_current_q2: 90.0,
            attendance_in_classes_current_q3: 92.5,
            attendance_in_classes_current_year: 89.0,
            classes_activity_cohort: "Cohort A",
            attendance_in_tests_current_q1: 80.0,
            attendance_in_tests_current_q2: 88.0,
            attendance_in_tests_current_q3: 90.5,
            attendance_in_tests_current_year: 86.2,
            tests_activity_cohort: "Cohort B",
            performance_trend_in_fst: "Improving",
            max_batch_score_in_latest_test: 95,
            average_batch_score_in_latest_test: 88.5,
            tests_number_of_correct_questions: 75,
            tests_number_of_wrong_questions: 10,
            tests_number_of_skipped_questions: 15,
            student_fkey_id: 1,
            user_profile: %{
              full_name: "John Doe",
              user_id: 1,
              email: "john.doe@example.com",
              gender: "Male",
              date_of_birth: "2000-01-15",
              role: "student",
              state: "California",
              country: "USA",
              current_grade: "11",
              current_program: "Science",
              current_batch: "Batch A",
              logged_in_atleast_once: true,
              first_session_accessed: "DemoTest_1",
              latest_session_accessed: "LiveClass_10"
            }
          })
        end
    }
  end
end
