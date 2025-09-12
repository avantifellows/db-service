defmodule Dbservice.UsersTest do
  use Dbservice.DataCase

  alias Dbservice.Users

  describe "user" do
    alias Dbservice.Users.User

    import Dbservice.UsersFixtures
    import Dbservice.GroupsFixtures

    @invalid_attrs %{
      first_name: nil,
      last_name: nil,
      email: nil,
      phone: "invalid number",
      gender: nil,
      address: nil,
      city: nil,
      district: nil,
      state: nil,
      region: nil,
      pincode: nil,
      role: nil,
      whatsapp_phone: nil,
      date_of_birth: nil,
      country: nil
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
        first_name: "some first name",
        last_name: "some last name",
        address: "some address",
        city: "some city",
        district: "some district",
        email: "some email",
        gender: "Male",
        phone: "9456591269",
        pincode: "123456",
        role: "user",
        state: "some state",
        whatsapp_phone: "9456591269",
        date_of_birth: ~D[1990-01-01],
        country: "some country"
      }

      assert {:ok, %User{} = user} = Users.create_user(valid_attrs)
      assert user.first_name == "some first name"
      assert user.last_name == "some last name"
      assert user.address == "some address"
      assert user.city == "some city"
      assert user.district == "some district"
      assert user.email == "some email"
      assert user.gender == "Male"
      assert user.phone == "9456591269"
      assert user.pincode == "123456"
      assert user.role == "user"
      assert user.state == "some state"
      assert user.whatsapp_phone == "9456591269"
      assert user.date_of_birth == ~D[1990-01-01]
      assert user.country == "some country"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()

      update_attrs = %{
        first_name: "some updated first name",
        last_name: "some updated last name",
        address: "some updated address",
        city: "some updated city",
        district: "some updated district",
        email: "some updated email",
        gender: "Female",
        phone: "9456591269",
        pincode: "updated pincode",
        role: "updated role",
        state: "updated state",
        whatsapp_phone: "updated whatsapp phone",
        date_of_birth: ~D[1995-05-15],
        country: "updated country"
      }

      assert {:ok, %User{} = user} = Users.update_user(user, update_attrs)
      assert user.first_name == "some updated first name"
      assert user.last_name == "some updated last name"
      assert user.address == "some updated address"
      assert user.city == "some updated city"
      assert user.district == "some updated district"
      assert user.email == "some updated email"
      assert user.gender == "Female"
      assert user.phone == "9456591269"
      assert user.pincode == "updated pincode"
      assert user.role == "updated role"
      assert user.state == "updated state"
      assert user.whatsapp_phone == "updated whatsapp phone"
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

    test "update_group/2 updates the group mapped to a user" do
      user = user_fixture()
      group1 = group_fixture()
      group2 = group_fixture()
      group3 = group_fixture()
      group_ids = [group1.id, group2.id, group3.id]

      assert {:ok, %User{} = updated_user} = Users.update_group(user.id, group_ids)
      assert Enum.any?(updated_user.group, fn g -> g.id == group1.id end)
      assert Enum.any?(updated_user.group, fn g -> g.id == group2.id end)
      assert Enum.any?(updated_user.group, fn g -> g.id == group3.id end)
    end

    test "update_group/2 with empty list removes all groups from the user" do
      user = user_fixture()
      group1 = group_fixture()
      group2 = group_fixture()
      group_ids = [group1.id, group2.id]

      {:ok, _} = Users.update_group(user.id, group_ids)
      assert {:ok, %User{} = updated_user} = Users.update_group(user.id, [])
      assert Enum.empty?(updated_user.group)
    end
  end

  describe "student" do
    alias Dbservice.Users.Student

    import Dbservice.UsersFixtures

    @invalid_attrs %{
      student_id: nil,
      father_name: nil,
      father_phone: nil,
      father_education_level: nil,
      father_profession: nil,
      mother_name: nil,
      mother_phone: nil,
      stream: nil,
      physically_handicapped: nil,
      annual_family_income: nil,
      father_profession: nil,
      father_education_level: nil,
      mother_profession: nil,
      mother_education_level: nil,
      mother_profession: nil,
      guardian_name: nil,
      guardian_relation: nil,
      guardian_phone: nil,
      guardian_education_level: nil,
      guardian_profession: nil,
      category: nil,
      has_category_certificate: nil,
      stream: nil,
      physically_handicapped: nil,
      physically_handicapped_certificate: nil,
      annual_family_income: nil,
      monthly_family_income: nil,
      time_of_device_availability: nil,
      has_internet_access: nil,
      primary_smartphone_owner: nil,
      primary_smartphone_owner_profession: nil,
      user_id: nil
    }

    test "list_student/0 returns all student" do
      {_user, student} = student_fixture()
      [head | _tail] = Users.list_student()

      assert Map.keys(head) == Map.keys(student)
    end

    test "get_student!/1 returns the student with given id" do
      {_user, student} = student_fixture()

      assert Users.get_student!(student.id) == student
    end

    test "create_student/1 with valid data creates a student" do
      valid_attrs = %{
        student_id: "some student id",
        category: "Gen",
        father_name: "some father_name",
        father_phone: "some father_phone",
        mother_name: "some mother_name",
        mother_phone: "some mother_phone",
        stream: "medical",
        physically_handicapped: false,
        annual_family_income: "some family income",
        father_profession: "some father profession",
        father_education_level: "some father education level",
        mother_profession: "some mother profession",
        mother_education_level: "some mother education level",
        has_internet_access: "false",
        primary_smartphone_owner: "some primary smartphone owner",
        primary_smartphone_owner_profession: "some primary smartphone owner profession",
        user_id: user_fixture().id
      }

      assert {:ok, %Student{} = student} = Users.create_student(valid_attrs)
      assert student.student_id == "some student id"
      assert student.category == "Gen"
      assert student.father_name == "some father_name"
      assert student.father_phone == "some father_phone"
      assert student.mother_name == "some mother_name"
      assert student.mother_phone == "some mother_phone"
      assert student.stream == "medical"
      assert student.physically_handicapped == false
      assert student.annual_family_income == "some family income"
      assert student.father_profession == "some father profession"
      assert student.father_education_level == "some father education level"
      assert student.mother_profession == "some mother profession"
      assert student.mother_education_level == "some mother education level"
      assert student.has_internet_access == "false"
      assert student.primary_smartphone_owner == "some primary smartphone owner"

      assert student.primary_smartphone_owner_profession ==
               "some primary smartphone owner profession"
    end

    test "create_student/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_student(@invalid_attrs)
    end

    test "update_student/2 with valid data updates the student" do
      {_user, student} = student_fixture()

      update_attrs = %{
        student_id: "some updated student id",
        category: "OBC",
        father_name: "some updated father_name",
        father_phone: "some updated father_phone",
        mother_name: "some updated mother_name",
        mother_phone: "some updated mother_phone",
        stream: "pcm",
        physically_handicapped: false,
        annual_family_income: "some updated family income",
        father_profession: "some updated father profession",
        father_education_level: "some updated father education level",
        mother_profession: "some updated mother profession",
        mother_education_level: "some updated mother education level",
        has_internet_access: "false",
        primary_smartphone_owner: "some updated primary smartphone owner",
        primary_smartphone_owner_profession: "some updated primary smartphone owner profession"
      }

      assert {:ok, %Student{} = student} = Users.update_student(student, update_attrs)
      assert student.student_id == "some updated student id"
      assert student.category == "OBC"
      assert student.father_name == "some updated father_name"
      assert student.father_phone == "some updated father_phone"
      assert student.mother_name == "some updated mother_name"
      assert student.mother_phone == "some updated mother_phone"
      assert student.stream == "pcm"
      assert student.physically_handicapped == false
      assert student.annual_family_income == "some updated family income"
      assert student.father_profession == "some updated father profession"
      assert student.father_education_level == "some updated father education level"
      assert student.mother_profession == "some updated mother profession"
      assert student.mother_education_level == "some updated mother education level"
      assert student.has_internet_access == "false"
      assert student.primary_smartphone_owner == "some updated primary smartphone owner"

      assert student.primary_smartphone_owner_profession ==
               "some updated primary smartphone owner profession"
    end

    test "update_student/2 with invalid data returns error changeset" do
      {_user, student} = student_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_student(student, @invalid_attrs)
      assert student == Users.get_student!(student.id)
    end

    test "delete_student/1 deletes the student" do
      {_user, student} = student_fixture()
      assert {:ok, %Student{}} = Users.delete_student(student)
      assert_raise Ecto.NoResultsError, fn -> Users.get_student!(student.id) end
    end

    test "change_student/1 returns a student changeset" do
      {_user, student} = student_fixture()
      assert %Ecto.Changeset{} = Users.change_student(student)
    end

    test "get_student_by_student_id/1 returns the student with given student_id" do
      {_user, student} = student_fixture()

      assert Users.get_student_by_student_id(student.student_id) == student
    end

    test "create_student_with_user/1 creates a user and then a student" do
      valid_attrs = %{
        first_name: "John",
        last_name: "Doe",
        address: "some address",
        city: "some city",
        district: "some district",
        email: "john.doe@example.com",
        gender: "male",
        phone: "9456591269",
        pincode: "123456",
        role: "user",
        state: "some state",
        whatsapp_phone: "9456591269",
        date_of_birth: ~D[1990-01-01],
        country: "some country",
        category: "Gen",
        father_name: "some father_name",
        father_phone: "some father_phone",
        mother_name: "some mother_name",
        mother_phone: "some mother_phone",
        stream: "medical",
        student_id: "some student id",
        physically_handicapped: false,
        annual_family_income: "some annual family income",
        monthly_family_income: "some monthly family income",
        father_profession: "some father profession",
        father_education_level: "some father education level",
        mother_profession: "some mother profession",
        mother_education_level: "some mother education level",
        has_internet_access: "false",
        primary_smartphone_owner: "some primary smartphone owner",
        primary_smartphone_owner_profession: "some primary smartphone owner profession"
      }

      assert {:ok, %Student{} = student} = Users.create_student_with_user(valid_attrs)
      assert student.category == "Gen"
      assert student.father_name == "some father_name"
      assert student.father_phone == "some father_phone"
    end

    test "update_student_with_user/3 updates a user and student" do
      {user, student} = student_fixture()

      update_attrs = %{
        first_name: "Updated First Name",
        last_name: "Updated Last Name",
        address: "some updated address",
        city: "some updated city",
        district: "some updated district",
        email: "updated.email@example",
        stream: "medical",
        father_name: "some father name",
        student_id: "some updated student id"
      }

      assert {:ok, %Student{} = updated_student} =
               Users.update_student_with_user(student, user, update_attrs)

      assert updated_student.category == "Gen"
      assert updated_student.father_name == "some father name"
      assert updated_student.stream == "medical"
    end
  end

  describe "teacher" do
    alias Dbservice.Users.Teacher

    import Dbservice.UsersFixtures

    @invalid_attrs %{
      designation: nil,
      user_id: nil
    }

    test "list_teacher/0 returns all teacher" do
      {_user, teacher} = teacher_fixture()
      [head | _tail] = Users.list_teacher()
      assert Map.keys(head) == Map.keys(teacher)
    end

    test "get_teacher!/1 returns the teacher with given id" do
      {_user, teacher} = teacher_fixture()

      assert Users.get_teacher!(teacher.id) == teacher
    end

    test "create_teacher/1 with valid data creates a teacher" do
      valid_attrs = %{
        teacher_id: "some teacher id",
        designation: "some designation",
        user_id: get_user_id_for_teacher()
      }

      assert {:ok, %Teacher{} = teacher} = Users.create_teacher(valid_attrs)
      assert teacher.teacher_id == "some teacher id"
      assert teacher.designation == "some designation"
    end

    test "create_teacher/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_teacher(@invalid_attrs)
    end

    test "update_teacher/2 with valid data updates the teacher" do
      {_user, teacher} = teacher_fixture()

      update_attrs = %{
        teacher_id: "some updated teacher id",
        designation: "some updated designation",
        user_id: get_user_id_for_teacher()
      }

      assert {:ok, %Teacher{} = teacher} = Users.update_teacher(teacher, update_attrs)
      assert teacher.teacher_id == "some updated teacher id"
      assert teacher.designation == "some updated designation"
    end

    test "update_teacher/2 with invalid data returns error changeset" do
      {_user, teacher} = teacher_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_teacher(teacher, @invalid_attrs)
      assert teacher == Users.get_teacher!(teacher.id)
    end

    test "delete_teacher/1 deletes the teacher" do
      {_user, teacher} = teacher_fixture()
      assert {:ok, %Teacher{}} = Users.delete_teacher(teacher)
      assert_raise Ecto.NoResultsError, fn -> Users.get_teacher!(teacher.id) end
    end

    test "change_teacher/1 returns a teacher changeset" do
      {_user, teacher} = teacher_fixture()
      assert %Ecto.Changeset{} = Users.change_teacher(teacher)
    end

    test "get_teacher_by_teacher_id/1 returns the teacher with given teacher_id" do
      {_user, teacher} = teacher_fixture()

      assert Users.get_teacher_by_teacher_id(teacher.teacher_id) == teacher
    end

    test "create_teacher_with_user/1 creates a user and then a teacher" do
      valid_attrs = %{
        designation: "some designation",
        teacher_id: "some teacher id",
        is_af_teacher: true,
        first_name: "John",
        last_name: "Doe",
        address: "some address",
        city: "some city",
        district: "some district",
        email: "john.doe@example.com",
        gender: "male",
        phone: "9456591269",
        pincode: "123456",
        role: "user",
        state: "some state",
        whatsapp_phone: "9456591269",
        date_of_birth: ~D[1990-01-01],
        country: "some country"
      }

      assert {:ok, %Teacher{} = teacher} = Users.create_teacher_with_user(valid_attrs)
      assert teacher.designation == "some designation"
      assert teacher.teacher_id == "some teacher id"
      assert teacher.is_af_teacher == true
    end

    test "update_teacher_with_user/3 updates a user and teacher" do
      {user, teacher} = teacher_fixture()

      update_attrs = %{
        designation: "some updated designation",
        teacher_id: "some updated teacher id",
        is_af_teacher: true,
        first_name: "Updated First Name",
        last_name: "Updated Last Name",
        address: "some updated address",
        city: "some updated city",
        district: "some updated district"
      }

      assert {:ok, %Teacher{} = updated_teacher} =
               Users.update_teacher_with_user(teacher, user, update_attrs)

      assert updated_teacher.designation == "some updated designation"
      assert updated_teacher.teacher_id == "some updated teacher id"
      assert updated_teacher.is_af_teacher == true
    end
  end
end
