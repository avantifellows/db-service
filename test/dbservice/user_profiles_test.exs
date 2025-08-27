defmodule Dbservice.ProfilesTest do
  use Dbservice.DataCase

  alias Dbservice.Profiles

  describe "user_profile" do
    alias Dbservice.Profiles.UserProfile

    import Dbservice.UserProfilesFixtures
    import Dbservice.UsersFixtures

    @invalid_attrs %{
      user_id: nil,
      current_grade: nil,
      current_program: nil,
      current_batch: nil,
      logged_in_atleast_once: nil,
      latest_session_accessed: nil
    }

    test "list_user_profile/0 returns all user profiles" do
      user_profile = user_profile_fixture()
      assert user_profile in Profiles.list_all_user_profiles()
    end

    test "get_user_profile!/1 returns the user profile with given id" do
      user_profile = user_profile_fixture()
      assert Profiles.get_user_profile!(user_profile.id) == user_profile
    end

    test "create_user_profile/1 with valid data creates a user profile" do
      user = user_fixture()

      valid_attrs = %{
        user_id: user.id,
        current_grade: "11",
        current_program: "HaryanaStudents",
        current_batch: "Photon",
        logged_in_atleast_once: true,
        latest_session_accessed: "LiveClass_10"
      }

      assert {:ok, %UserProfile{} = user_profile} = Profiles.create_user_profile(valid_attrs)
    end

    test "create_user_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Profiles.create_user_profile(@invalid_attrs)
    end

    test "update_user_profile/2 with valid data updates the user profile" do
      user_profile = user_profile_fixture()

      update_attrs = %{
        user_id: user_profile.user_id,
        current_grade: "11",
        current_program: "HaryanaStudents",
        current_batch: "Photon",
        latest_session_accessed: "LiveClass_10"
      }

      assert {:ok, %UserProfile{} = user_profile} =
               Profiles.update_user_profile(user_profile, update_attrs)
    end

    test "update_user_profile/2 with invalid data returns error changeset" do
      user_profile = user_profile_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Profiles.update_user_profile(user_profile, @invalid_attrs)

      assert user_profile == Profiles.get_user_profile!(user_profile.id)
    end

    test "delete_user_profile/1 deletes the user profile" do
      user_profile = user_profile_fixture()
      assert {:ok, %UserProfile{}} = Profiles.delete_user_profile(user_profile)
      assert_raise Ecto.NoResultsError, fn -> Profiles.get_user_profile!(user_profile.id) end
    end

    test "change_user_profile/1 returns a user profile changeset" do
      user_profile = user_profile_fixture()
      assert %Ecto.Changeset{} = Profiles.change_user_profile(user_profile)
    end
  end

  describe "student_profile" do
    alias Dbservice.Profiles

    import Dbservice.UserProfilesFixtures
    import Dbservice.UsersFixtures
    alias Dbservice.Profiles.StudentProfile

    @invalid_attrs %{
      student_fk: nil,
      student_id: nil,
      user_profile_id: nil,
      took_test_atleast_once: nil,
      took_class_atleast_once: nil,
      total_number_of_tests: nil,
      total_number_of_live_classes: nil,
      attendance_in_classes_current_year: nil,
      classes_activity_cohort: nil,
      attendance_in_tests_current_year: nil,
      tests_activity_cohort: nil,
      performance_trend_in_fst: nil,
      max_batch_score_in_latest_test: nil,
      average_batch_score_in_latest_test: nil,
      tests_number_of_correct_questions: nil,
      tests_number_of_wrong_questions: nil,
      tests_number_of_skipped_questions: nil
    }

    test "list_student_profile/0 returns all student profiles" do
      student_profile = student_profile_fixture()
      assert student_profile in Profiles.list_student_profiles()
    end

    test "get_student_profile!/1 returns the student profile with given id" do
      student_profile = student_profile_fixture()
      assert Profiles.get_student_profile!(student_profile.id) == student_profile
    end

    test "create_student_profile/1 with valid data creates a student profile" do
      {_user, student} = student_fixture()
      user_profile = user_profile_fixture()

      valid_attrs = %{
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
        user_profile_id: user_profile.id
      }

      assert {:ok, %StudentProfile{} = student_profile} =
               Profiles.create_student_profile(valid_attrs)

      assert student_profile.student_id == "10101"
      assert student_profile.took_test_atleast_once == true
    end

    test "create_student_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Profiles.create_student_profile(@invalid_attrs)
    end

    test "update_student_profile/2 with valid data updates the student profile" do
      student_profile = student_profile_fixture()

      update_attrs = %{
        student_fk: student_profile.student_fk,
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
        tests_number_of_skipped_questions: 15
      }

      assert {:ok, %StudentProfile{} = student_profile} =
               Profiles.update_student_profile(student_profile, update_attrs)

      assert student_profile.student_id == "10101"
    end

    test "update_student_profile/2 with invalid data returns error changeset" do
      student_profile = student_profile_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Profiles.update_student_profile(student_profile, @invalid_attrs)

      assert student_profile == Profiles.get_student_profile!(student_profile.id)
    end

    test "delete_student_profile/1 deletes the student profile" do
      student_profile = student_profile_fixture()
      assert {:ok, %StudentProfile{}} = Profiles.delete_student_profile(student_profile)

      assert_raise Ecto.NoResultsError, fn ->
        Profiles.get_student_profile!(student_profile.id)
      end
    end

    test "change_student_profile/1 returns a student profile changeset" do
      student_profile = student_profile_fixture()
      assert %Ecto.Changeset{} = Profiles.change_student_profile(student_profile)
    end

    test "create_student_profile_with_user_profile creates a user profile and student profile" do
      {user, student} = student_fixture()

      valid_attrs = %{
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
        current_grade: "11",
        current_program: "HaryanaStudents",
        current_batch: "Photon",
        logged_in_atleast_once: true,
        latest_session_accessed: "LiveClass_10",
        user_id: user.id
      }

      assert {:ok, %StudentProfile{} = student_profile} =
               Profiles.create_student_profile_with_user_profile(valid_attrs)

      assert student_profile.student_id == "10101"
      assert student_profile.took_test_atleast_once == true
    end

    test "update_student_profile_with_user_profile/3 updates the student profile and user profile" do
      student_profile = student_profile_fixture()

      user_profile = Profiles.get_user_profile!(student_profile.user_profile_id)

      update_attrs = %{
        student_fk: student_profile.student_fk,
        student_id: "10107",
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
        tests_number_of_skipped_questions: 15
      }

      assert {:ok, %StudentProfile{} = student_profile} =
               Profiles.update_student_profile_with_user_profile(
                 student_profile,
                 user_profile,
                 update_attrs
               )

      assert student_profile.student_id == "10107"
    end
  end

  describe "teacher_profile" do
    alias Dbservice.Profiles.TeacherProfile
    import Dbservice.UserProfilesFixtures
    import Dbservice.UsersFixtures
    alias Dbservice.Profiles

    @invalid_attrs %{
      teacher_id: nil,
      school: nil,
      program_manager: nil,
      user_profile_id: nil,
      teacher_fk: nil
    }

    test "list_teacher_profile/0 returns all teacher profiles" do
      teacher_profile = teacher_profile_fixture()
      assert teacher_profile in Profiles.list_teacher_profiles()
    end

    test "get_teacher_profile!/1 returns the teacher profile with given id" do
      teacher_profile = teacher_profile_fixture()
      assert Profiles.get_teacher_profile!(teacher_profile.id) == teacher_profile
    end

    test "create_teacher_profile/1 with valid data creates a teacher profile" do
      {user, _subject, teacher} = teacher_fixture()
      user_profile = user_profile_fixture()

      valid_attrs = %{
        teacher_id: "1010",
        teacher_fk: teacher.id,
        school: "XYZ High School",
        program_manager: "John Doe",
        user_profile_id: user_profile.id,
        user_id: user.id,
        avg_rating: 4.5,
        logged_in_atleast_once: false,
        latest_session_accessed: "LiveClass_10"
      }

      assert {:ok, %TeacherProfile{} = teacher_profile} =
               Profiles.create_teacher_profile(valid_attrs)

      assert teacher_profile.program_manager == "John Doe"
      assert teacher_profile.school == "XYZ High School"
    end

    test "create_teacher_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Profiles.create_teacher_profile(@invalid_attrs)
    end

    test "update_teacher_profile/2 with valid data updates the teacher profile" do
      teacher_profile = teacher_profile_fixture()

      update_attrs = %{
        teacher_id: "1010",
        school: "Some High School",
        program_manager: "John Doe"
      }

      assert {:ok, %TeacherProfile{} = teacher_profile} =
               Profiles.update_teacher_profile(teacher_profile, update_attrs)

      assert teacher_profile.school == "Some High School"
    end

    test "update_student_profile/2 with invalid data returns error changeset" do
      teacher_profile = teacher_profile_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Profiles.update_teacher_profile(teacher_profile, @invalid_attrs)

      assert teacher_profile == Profiles.get_teacher_profile!(teacher_profile.id)
    end

    test "delete_teacher_profile/1 deletes the teacher profile" do
      teacher_profile = teacher_profile_fixture()
      assert {:ok, %TeacherProfile{}} = Profiles.delete_teacher_profile(teacher_profile)

      assert_raise Ecto.NoResultsError, fn ->
        Profiles.get_teacher_profile!(teacher_profile.id)
      end
    end

    test "change_teacher_profile/1 returns a teacher profile changeset" do
      teacher_profile = teacher_profile_fixture()
      assert %Ecto.Changeset{} = Profiles.change_teacher_profile(teacher_profile)
    end

    test "create_teacher_profile_with_user_profile creates a user profile and teacher profile" do
      {user, _subject, teacher} = teacher_fixture()
      user_profile = user_profile_fixture()

      valid_attrs = %{
        teacher_id: "1010",
        teacher_fk: teacher.id,
        school: "XYZ High School",
        program_manager: "John Doe",
        user_profile_id: user_profile.id,
        user_id: user.id
      }

      assert {:ok, %TeacherProfile{} = teacher_profile} =
               Profiles.create_teacher_profile_with_user_profile(valid_attrs)

      assert teacher_profile.teacher_id == "1010"
      assert teacher_profile.school == "XYZ High School"
    end

    test "update_teacher_profile_with_user_profile/3 updates the teacher profile and user profile" do
      teacher_profile = teacher_profile_fixture()

      user_profile = Profiles.get_user_profile!(teacher_profile.user_profile_id)

      update_attrs = %{
        teacher_id: "1010",
        school: "Some High School",
        program_manager: "John Doe"
      }

      assert {:ok, %TeacherProfile{} = teacher_profile} =
               Profiles.update_teacher_profile_with_user_profile(
                 teacher_profile,
                 user_profile,
                 update_attrs
               )

      assert teacher_profile.school == "Some High School"
    end
  end
end
