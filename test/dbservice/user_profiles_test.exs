defmodule Dbservice.ProfilesTest do
  use Dbservice.DataCase

  alias Dbservice.Profiles

  describe "user_profile" do
    alias Dbservice.Profiles.UserProfile

    import Dbservice.ProfilesFixtures

    @invalid_attrs %{
      user_id: nil
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
      valid_attrs = %{
        user_id: get_user_id(),
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
        user_id: get_user_id(),
        logged_in_atleast_once: true,
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

    @invalid_attrs %{
      student_fk: nil,
      student_id: nil,
      user_profile_id: nil
    }

    test "list_student_profile/0 returns all student profiles" do
      student_profile = student_profile_fixture()
      assert student_profile in Profiles.list_student_profiles()
    end

    test "get_student_profile!/1 returns the student profile with given id" do
      student_profile = student_profile_fixture()
      assert StudentProfiles.get_student_profile!(student_profile.id) == student_profile
    end

    test "create_student_profile/1 with valid data creates a student profile" do
      {user_id, student_fk} = get_user_id_and_student_fk()

      valid_attrs = %{
        student_fk: student_fk,
        student_id: "100110",
        took_test_atleast_once: true,
        took_class_atleast_once: true,
        total_number_of_tests: 20,
        total_number_of_live_classes: 50,
        attendance_in_classes_current_year: [89.0, 12.0],
        classes_activity_cohort: "Cohort A",
        attendance_in_tests_current_year: [86.2, 11.1],
        tests_activity_cohort: "Cohort B",
        performance_trend_in_fst: "Improving",
        max_batch_score_in_latest_test: 95,
        average_batch_score_in_latest_test: 88.5,
        tests_number_of_correct_questions: 75,
        tests_number_of_wrong_questions: 10,
        tests_number_of_skipped_questions: 15,
        user_id: user_id,
        logged_in_atleast_once: true,
        latest_session_accessed: "LiveClass_10"
      }

      assert {:ok, %StudentProfile{} = student_profile} =
               Profiles.create_student_profile_with_user_profile(valid_attrs)

      assert student_profile.logged_in_atleast_once == true
    end

    test "create_student_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = StudentProfiles.create_student_profile(@invalid_attrs)
    end
  end

  describe "teacher_profile" do
    alias Dbservice.Profiles.TeacherProfiles

    import Dbservice.UserProfilesFixtures

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
      {user_id, teacher_fk} = get_user_id_and_teacher_fk_for_teacher_profile()

      valid_attrs = %{
        teacher_id: "1010",
        teacher_fk: teacher_fk,
        school: "XYZ High School",
        program_manager: "John Doe",
        avg_rating: 4.5,
        user_id: user_id,
        logged_in_atleast_once: false,
        latest_session_accessed: "LiveClass_10"
      }

      assert {:ok, %TeacherProfile{} = teacher_profile} =
               TeacherProfiles.create_teacher_profile_with_user_profile(valid_attrs)

      assert teacher_profile.program_name == "John Doe"
      assert teacher_profile.logged_in_atleast_once == false
    end

    test "create_teacher_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TeacherProfiles.create_teacher_profile(@invalid_attrs)
    end
  end
end
