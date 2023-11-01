defmodule Dbservice.UserProfilesFixtures do
  alias Dbservice.Users
  alias Dbservice.Profiles
  alias Dbservice.UsersFixtures

  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Profiles` context.
  """

  def user_profile_fixture(attrs \\ %{}) do
    user = UsersFixtures.user_fixture()

    {:ok, user_profile} =
      attrs
      |> Enum.into(%{
        user_id: user.id,
        full_name: "John Doe",
        email: "johndoe@example.com",
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
      |> Profiles.create_user_profile()

    user_profile
  end

  def student_profile_fixture(attrs \\ %{}) do
    student = UsersFixtures.student_fixture()

    {:ok, student_profile} =
      attrs
      |> Enum.into(%{
        student_fkey_id: student.id,
        student_id: "some-student-id",
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
        user_id: get_user_id(),
        full_name: "John Doe",
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
      |> Profiles.create_student_profile_with_user_profile()

    student_profile
  end

  def teacher_profile_fixture(attrs \\ %{}) do
    teacher = UsersFixtures.teacher_fixture()

    {:ok, teacher_profile} =
      attrs
      |> Enum.into(%{
        teacher_id: teacher.id,
        uuid: "some-uuid",
        designation: "Math Teacher",
        subject: "Mathematics",
        school: "XYZ High School",
        program_manager: "John Doe",
        avg_rating: 4.5,
        full_name: "John Doe",
        user_id: get_user_id_for_teacher(),
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
      |> Profiles.create_teacher_profile_with_user_profile()

    teacher_profile
  end

  def get_user_id do
    [head | _tail] = Users.list_student()
    user_id = head.user_id
    user_id
  end

  def get_user_id_for_teacher do
    [head | _tail] = Users.list_teacher()
    user_id = head.user_id
    user_id
  end
end
