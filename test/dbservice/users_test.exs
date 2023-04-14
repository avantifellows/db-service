defmodule Dbservice.UsersTest do
  use Dbservice.DataCase

  alias Dbservice.Users

  describe "user" do
    alias Dbservice.Users.User

    import Dbservice.UsersFixtures

    @invalid_attrs %{
      full_name: nil,
      email: nil,
      phone: "nope",
      gender: nil,
      address: nil,
      city: nil,
      district: nil,
      state: nil,
      pincode: nil,
      role: nil,
      whatsapp_phone: nil,
      date_of_birth: nil
    }

    test "list_user/0 returns all user" do
      user = user_fixture()
      [head | _tail] = Users.list_all_users()
      assert Map.keys(head) == Map.keys(user)
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Users.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{
        address: "some address",
        city: "some city",
        district: "some district",
        email: "some email",
        full_name: "some full name",
        gender: "some gender",
        phone: "9456591269",
        pincode: "some pincode",
        role: "some role",
        state: "some state",
        whatsapp_phone: "some whatsapp phone",
        date_of_birth: ~U[2022-04-28 13:58:00Z]
      }

      assert {:ok, %User{} = user} = Users.create_user(valid_attrs)
      assert user.address == "some address"
      assert user.city == "some city"
      assert user.district == "some district"
      assert user.email == "some email"
      assert user.full_name == "some full name"
      assert user.gender == "some gender"
      assert user.phone == "9456591269"
      assert user.pincode == "some pincode"
      assert user.role == "some role"
      assert user.state == "some state"
      assert user.whatsapp_phone == "some whatsapp phone"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()

      update_attrs = %{
        address: "some updated address",
        city: "some updated city",
        district: "some updated district",
        email: "some updated email",
        full_name: "some updated full name",
        gender: "some updated gender",
        phone: "9456591269",
        pincode: "some updated pincode",
        role: "some updated role",
        state: "some updated state",
        whatsapp_phone: "some updated whatsapp phone",
        date_of_birth: ~U[2022-04-28 13:58:00Z]
      }

      assert {:ok, %User{} = user} = Users.update_user(user, update_attrs)
      assert user.address == "some updated address"
      assert user.city == "some updated city"
      assert user.district == "some updated district"
      assert user.email == "some updated email"
      assert user.full_name == "some updated full name"
      assert user.gender == "some updated gender"
      assert user.phone == "9456591269"
      assert user.pincode == "some updated pincode"
      assert user.role == "some updated role"
      assert user.state == "some updated state"
      assert user.whatsapp_phone == "some updated whatsapp phone"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_user(user, @invalid_attrs)
      assert user == Users.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Users.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Users.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Users.change_user(user)
    end
  end

  describe "student" do
    alias Dbservice.Users.Student

    import Dbservice.UsersFixtures

    @invalid_attrs %{
      category: nil,
      father_name: nil,
      father_phone: nil,
      mother_name: nil,
      mother_phone: nil,
      stream: nil,
      uuid: nil,
      physically_handicapped: nil,
      family_income: nil,
      father_profession: nil,
      father_education_level: nil,
      mother_profession: nil,
      mother_education_level: nil,
      time_of_device_availability: nil,
      has_internet_access: nil,
      primary_smartphone_owner: nil,
      primary_smartphone_owner_profession: nil,
      user_id: nil,
      group_id: nil
    }

    test "list_student/0 returns all student" do
      student = student_fixture()
      [head | _tail] = Users.list_student()
      assert Map.keys(head) == Map.keys(student)
    end

    test "get_student!/1 returns the student with given id" do
      student = student_fixture()
      assert Users.get_student!(student.id) == student
    end

    test "create_student/1 with valid data creates a student" do
      valid_attrs = %{
        category: "some category",
        father_name: "some father_name",
        father_phone: "some father_phone",
        mother_name: "some mother_name",
        mother_phone: "some mother_phone",
        stream: "some stream",
        student_id: "some student id",
        physically_handicapped: false,
        family_income: "some family income",
        father_profession: "some father profession",
        father_education_level: "some father education level",
        mother_profession: "some mother profession",
        mother_education_level: "some mother education level",
        has_internet_access: false,
        primary_smartphone_owner: "some primary smartphone owner",
        primary_smartphone_owner_profession: "some primary smartphone owner profession",
        user_id: get_user_id()
      }

      assert {:ok, %Student{} = student} = Users.create_student(valid_attrs)
      assert student.category == "some category"
      assert student.father_name == "some father_name"
      assert student.father_phone == "some father_phone"
      assert student.mother_name == "some mother_name"
      assert student.mother_phone == "some mother_phone"
      assert student.stream == "some stream"
      assert student.student_id == "some student id"
      assert student.physically_handicapped == false
      assert student.family_income == "some family income"
      assert student.father_profession == "some father profession"
      assert student.father_education_level == "some father education level"
      assert student.mother_profession == "some mother profession"
      assert student.mother_education_level == "some mother education level"
      assert student.has_internet_access == false
      assert student.primary_smartphone_owner == "some primary smartphone owner"

      assert student.primary_smartphone_owner_profession ==
               "some primary smartphone owner profession"
    end

    test "create_student/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_student(@invalid_attrs)
    end

    test "update_student/2 with valid data updates the student" do
      student = student_fixture()

      update_attrs = %{
        category: "some updated category",
        father_name: "some updated father_name",
        father_phone: "some updated father_phone",
        mother_name: "some updated mother_name",
        mother_phone: "some updated mother_phone",
        stream: "some updated stream",
        student_id: "some updated student id",
        physically_handicapped: false,
        family_income: "some updated family income",
        father_profession: "some updated father profession",
        father_education_level: "some updated father education level",
        mother_profession: "some updated mother profession",
        mother_education_level: "some updated mother education level",
        has_internet_access: false,
        primary_smartphone_owner: "some updated primary smartphone owner",
        primary_smartphone_owner_profession: "some updated primary smartphone owner profession",
        user_id: get_user_id()
      }

      assert {:ok, %Student{} = student} = Users.update_student(student, update_attrs)
      assert student.category == "some updated category"
      assert student.father_name == "some updated father_name"
      assert student.father_phone == "some updated father_phone"
      assert student.mother_name == "some updated mother_name"
      assert student.mother_phone == "some updated mother_phone"
      assert student.stream == "some updated stream"
      assert student.student_id == "some updated student id"
      assert student.physically_handicapped == false
      assert student.family_income == "some updated family income"
      assert student.father_profession == "some updated father profession"
      assert student.father_education_level == "some updated father education level"
      assert student.mother_profession == "some updated mother profession"
      assert student.mother_education_level == "some updated mother education level"
      assert student.has_internet_access == false
      assert student.primary_smartphone_owner == "some updated primary smartphone owner"

      assert student.primary_smartphone_owner_profession ==
               "some updated primary smartphone owner profession"
    end

    test "update_student/2 with invalid data returns error changeset" do
      student = student_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_student(student, @invalid_attrs)
      assert student == Users.get_student!(student.id)
    end

    test "delete_student/1 deletes the student" do
      student = student_fixture()
      assert {:ok, %Student{}} = Users.delete_student(student)
      assert_raise Ecto.NoResultsError, fn -> Users.get_student!(student.id) end
    end

    test "change_student/1 returns a student changeset" do
      student = student_fixture()
      assert %Ecto.Changeset{} = Users.change_student(student)
    end
  end

  describe "teacher" do
    alias Dbservice.Users.Teacher

    import Dbservice.UsersFixtures

    @invalid_attrs %{
      designation: nil,
      grade: nil,
      subject: nil,
      uuid: nil,
      user_id: nil,
      school_id: nil,
      program_manager_id: nil
    }

    test "list_teacher/0 returns all teacher" do
      teacher = teacher_fixture()
      [head | _tail] = Users.list_teacher()
      assert Map.keys(head) == Map.keys(teacher)
    end

    test "get_teacher!/1 returns the teacher with given id" do
      teacher = teacher_fixture()
      assert Users.get_teacher!(teacher.id) == teacher
    end

    test "create_teacher/1 with valid data creates a teacher" do
      valid_attrs = %{
        designation: "some designation",
        grade: "some grade",
        subject: "some subject",
        uuid: "some uuid",
        user_id: get_user_id_for_teacher(),
        school_id: get_school_id(),
        program_manager_id: get_program_manager_id()
      }

      assert {:ok, %Teacher{} = teacher} = Users.create_teacher(valid_attrs)
      assert teacher.designation == "some designation"
      assert teacher.grade == "some grade"
      assert teacher.subject == "some subject"
    end

    test "create_teacher/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_teacher(@invalid_attrs)
    end

    test "update_teacher/2 with valid data updates the teacher" do
      teacher = teacher_fixture()

      update_attrs = %{
        designation: "some updated designation",
        grade: "some updated grade",
        subject: "some updated subject",
        user_id: get_user_id_for_teacher(),
        school_id: get_school_id(),
        program_manager_id: get_program_manager_id()
      }

      assert {:ok, %Teacher{} = teacher} = Users.update_teacher(teacher, update_attrs)
      assert teacher.designation == "some updated designation"
      assert teacher.grade == "some updated grade"
      assert teacher.subject == "some updated subject"
    end

    test "update_teacher/2 with invalid data returns error changeset" do
      teacher = teacher_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_teacher(teacher, @invalid_attrs)
      assert teacher == Users.get_teacher!(teacher.id)
    end

    test "delete_teacher/1 deletes the teacher" do
      teacher = teacher_fixture()
      assert {:ok, %Teacher{}} = Users.delete_teacher(teacher)
      assert_raise Ecto.NoResultsError, fn -> Users.get_teacher!(teacher.id) end
    end

    test "change_teacher/1 returns a teacher changeset" do
      teacher = teacher_fixture()
      assert %Ecto.Changeset{} = Users.change_teacher(teacher)
    end
  end
end
