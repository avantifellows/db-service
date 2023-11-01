defmodule Dbservice.ProfilesTest do
  use Dbservice.DataCase

  alias Dbservice.Profiles

  describe "user_profile" do
    alias Dbservice.Profiles.UserProfile

    import Dbservice.ProfilesFixtures

    @invalid_attrs %{
      user_id: nil,
      full_name: nil,
      email: nil,
      role: nil
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
      }

      assert {:ok, %UserProfile{} = user_profile} = Profiles.create_user_profile(valid_attrs)
      assert user_profile.full_name == "John Doe"
      assert user_profile.email == "johndoe@example.com"
      assert user_profile.gender == "Male"
      assert user_profile.date_of_birth == "2003-08-22"
      assert user_profile.role == "student"
      assert user_profile.state == "Maharashtra"
      assert user_profile.country == "India"
      assert user_profile.current_grade == "11"
    end

    test "create_user_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Profiles.create_user_profile(@invalid_attrs)
    end

    test "update_user_profile/2 with valid data updates the user profile" do
      user_profile = user_profile_fixture()

      update_attrs = %{
        user_id: get_user_id(),
        full_name: "John Dodoe",
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
      }

      assert {:ok, %UserProfile{} = user_profile} =
               Profiles.update_user_profile(user_profile, update_attrs)

      assert user_profile.full_name == "John Dodoe"
      assert user_profile.email == "johndoe@example.com"
      assert user_profile.gender == "Male"
      assert user_profile.date_of_birth == "2003-08-22"
      assert user_profile.role == "student"
      assert user_profile.state == "Maharashtra"
      assert user_profile.country == "India"
      assert user_profile.current_grade == "11"
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
      student_fkey_id: nil,
      student_id: nil,
      father_education_level: nil,
      mother_education_level: nil,
      category: nil,
      stream: nil,
      annual_family_income: nil,
      has_internet_access: nil,
      user_id: nil,
      full_name: nil,
      email: nil,
      role: nil
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
      valid_attrs = %{
        student_fkey_id: 1,
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
      }

      assert {:ok, %StudentProfile{} = student_profile} =
               Profiles.create_student_profile_with_user_profile(valid_attrs)

      assert student_profile.full_name == "John Doe"
      assert student_profile.logged_in_atleast_once == true
    end

    test "create_student_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = StudentProfiles.create_student_profile(@invalid_attrs)
    end
  end

  describe "teacher_profile" do
    alias Dbservice.Profiles.rProfiles()

    import Dbservice.UserProfilesFixtures

    @invalid_attrs %{
      teacher_id: nil,
      designation: nil,
      subject: nil,
      school: nil,
      program_manager: nil,
      user_id: nil,
      full_name: nil,
      email: nil,
      role: nil
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
      valid_attrs = %{
        teacher_id: 1,
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
      }

      assert {:ok, %TeacherProfile{} = teacher_profile} =
               TeacherProfiles.create_teacher_profile_with_user_profile(valid_attrs)

      assert teacher_profile.full_name == "John Doe"
      assert teacher_profile.logged_in_atleast_once == false
    end

    test "create_teacher_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TeacherProfiles.create_teacher_profile(@invalid_attrs)
    end
  end
end
