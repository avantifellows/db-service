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
        current_grade: "11",
        current_program: "HaryanaStudents",
        current_batch: "Photon",
        logged_in_atleast_once: true,
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
        student_fk: student.id,
        student_id: "10101",
        took_test_atleast_once: true,
        took_class_atleast_once: true,
        total_number_of_tests: 20,
        total_number_of_live_classes: 50,
        attendance_in_classes_current_year: [89.0, 11.1],
        classes_activity_cohort: "Cohort A",
        attendance_in_tests_current_year: [86.2, 11.1],
        tests_activity_cohort: "Cohort B",
        performance_trend_in_fst: "Improving",
        max_batch_score_in_latest_test: 95,
        average_batch_score_in_latest_test: 88.5,
        tests_number_of_correct_questions: 75,
        tests_number_of_wrong_questions: 10,
        tests_number_of_skipped_questions: 15,
        user_id: student.user_id,
        current_grade: "11",
        current_program: "Science",
        current_batch: "Batch A",
        logged_in_atleast_once: true,
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
        teacher_id: "100101",
        teacher_fk: teacher.id,
        school: "XYZ High School",
        program_manager: "John Doe",
        avg_rating: 4.5,
        user_id: teacher.user_id,
        current_grade: "11",
        current_program: "HaryanaStudents",
        current_batch: "Photon",
        logged_in_atleast_once: false,
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

  def get_user_id_and_student_fk do
    [head | _tail] = Users.list_student()
    user_id = head.user_id
    student_fk = head.id
    {user_id, student_fk}
  end

  def get_user_id_and_teacher_fk do
    [head | _tail] = Users.list_teacher()
    user_id = head.user_id
    teacher_fk = head.id
    {user_id, teacher_fk}
  end
end
