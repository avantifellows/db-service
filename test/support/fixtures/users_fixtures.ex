defmodule Dbservice.UsersFixtures do
  alias Dbservice.Users

  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Users` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        first_name: "some first name",
        last_name: "some last name",
        email: "some email",
        phone: "9456591269",
        gender: "some gender",
        address: "some address",
        city: "some city",
        district: "some district",
        state: "some state",
        region: "some region",
        pincode: "some pincode",
        role: "some role",
        whatsapp_phone: "some whatsapp phone",
        date_of_birth: ~D[2000-01-01],
        country: "some country"
      })
      |> Dbservice.Users.create_user()

    user
  end

  @doc """
  Generate a student.
  """
  def student_fixture(attrs \\ %{}) do
    {:ok, student} =
      attrs
      |> Enum.into(%{
        category: "some category",
        father_name: "some father_name",
        father_phone: "some father_phone",
        mother_name: "some mother_name",
        mother_phone: "some mother_phone",
        stream: "some stream",
        uuid: "some uuid",
        physically_handicapped: false,
        family_income: "some family income",
        father_profession: "some father profession",
        father_education_level: "some father education level",
        mother_profession: "some mother profession",
        mother_education_level: "some mother education level",
        time_of_device_availability: ~U[2022-04-28 13:58:00Z],
        has_internet_access: false,
        primary_smartphone_owner: "some primary smartphone owner",
        primary_smartphone_owner_profession: "some primary smartphone owner profession",
        user_id: get_user_id()
      })
      |> Dbservice.Users.create_student()

    student
  end

  @doc """
  Generate a teacher.
  """
  def teacher_fixture(attrs \\ %{}) do
    {:ok, teacher} =
      attrs
      |> Enum.into(%{
        designation: "some designation",
        grade: "some grade",
        subject: "some subject",
        uuid: "some uuid",
        user_id: get_user_id_for_teacher(),
        school_id: get_school_id(),
        program_manager_id: get_program_manager_id()
      })
      |> Dbservice.Users.create_teacher()

    teacher
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

  def get_school_id do
    [head | _tail] = Users.list_teacher()
    school_id = head.school_id
    school_id
  end

  def get_program_manager_id do
    [head | _tail] = Users.list_teacher()
    program_manager_id = head.program_manager_id
    program_manager_id
  end
end
