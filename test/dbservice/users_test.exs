defmodule Dbservice.UsersTest do
  use Dbservice.DataCase

  alias Dbservice.Users

  describe "user" do
    alias Dbservice.Users.User

    import Dbservice.UsersFixtures

    @invalid_attrs %{
      address: nil,
      city: nil,
      district: nil,
      email: nil,
      first_name: nil,
      gender: nil,
      last_name: nil,
      phone: nil,
      pincode: nil,
      role: nil,
      state: nil
    }

    test "list_user/0 returns all user" do
      user = user_fixture()
      assert Users.list_user() == [user]
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
        first_name: "some first_name",
        gender: "some gender",
        last_name: "some last_name",
        phone: "some phone",
        pincode: "some pincode",
        role: "some role",
        state: "some state"
      }

      assert {:ok, %User{} = user} = Users.create_user(valid_attrs)
      assert user.address == "some address"
      assert user.city == "some city"
      assert user.district == "some district"
      assert user.email == "some email"
      assert user.first_name == "some first_name"
      assert user.gender == "some gender"
      assert user.last_name == "some last_name"
      assert user.phone == "some phone"
      assert user.pincode == "some pincode"
      assert user.role == "some role"
      assert user.state == "some state"
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
        first_name: "some updated first_name",
        gender: "some updated gender",
        last_name: "some updated last_name",
        phone: "some updated phone",
        pincode: "some updated pincode",
        role: "some updated role",
        state: "some updated state"
      }

      assert {:ok, %User{} = user} = Users.update_user(user, update_attrs)
      assert user.address == "some updated address"
      assert user.city == "some updated city"
      assert user.district == "some updated district"
      assert user.email == "some updated email"
      assert user.first_name == "some updated first_name"
      assert user.gender == "some updated gender"
      assert user.last_name == "some updated last_name"
      assert user.phone == "some updated phone"
      assert user.pincode == "some updated pincode"
      assert user.role == "some updated role"
      assert user.state == "some updated state"
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
      uuid: nil
    }

    test "list_student/0 returns all student" do
      student = student_fixture()
      assert Users.list_student() == [student]
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
        uuid: "some uuid"
      }

      assert {:ok, %Student{} = student} = Users.create_student(valid_attrs)
      assert student.category == "some category"
      assert student.father_name == "some father_name"
      assert student.father_phone == "some father_phone"
      assert student.mother_name == "some mother_name"
      assert student.mother_phone == "some mother_phone"
      assert student.stream == "some stream"
      assert student.uuid == "some uuid"
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
        uuid: "some updated uuid"
      }

      assert {:ok, %Student{} = student} = Users.update_student(student, update_attrs)
      assert student.category == "some updated category"
      assert student.father_name == "some updated father_name"
      assert student.father_phone == "some updated father_phone"
      assert student.mother_name == "some updated mother_name"
      assert student.mother_phone == "some updated mother_phone"
      assert student.stream == "some updated stream"
      assert student.uuid == "some updated uuid"
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

    @invalid_attrs %{designation: nil, grade: nil, subject: nil}

    test "list_teacher/0 returns all teacher" do
      teacher = teacher_fixture()
      assert Users.list_teacher() == [teacher]
    end

    test "get_teacher!/1 returns the teacher with given id" do
      teacher = teacher_fixture()
      assert Users.get_teacher!(teacher.id) == teacher
    end

    test "create_teacher/1 with valid data creates a teacher" do
      valid_attrs = %{
        designation: "some designation",
        grade: "some grade",
        subject: "some subject"
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
        subject: "some updated subject"
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
