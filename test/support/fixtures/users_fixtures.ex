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
        address: "some address",
        city: "some city",
        district: "some district",
        email: "some email",
        gender: "Male",
        phone: "9456591269",
        pincode: "some pincode",
        state: "some state",
        region: "some region",
        pincode: "123456",
        role: "student",
        whatsapp_phone: "9456591269",
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
    user = user_fixture()
    user_id = user.id

    {:ok, student} =
      attrs
      |> Enum.into(%{
        student_id: "some student id",
        category: "Gen",
        father_name: "some father_name",
        father_phone: "some father_phone",
        mother_name: "some mother_name",
        stream: "medical",
        physically_handicapped: false,
        annual_family_income: "some family income",
        father_education_level: "some father education level",
        father_profession: "some father profession",
        mother_phone: "some mother phone",
        mother_education_level: "some mother education level",
        time_of_device_availability: "morning",
        has_internet_access: "false",
        primary_smartphone_owner: "some primary smartphone owner",
        primary_smartphone_owner_profession: "some primary smartphone owner profession",
        user_id: user_id
      })
      |> Dbservice.Users.create_student()

    {user, student}
  end

  @doc """
  Generate a teacher.
  """
  def teacher_fixture(attrs \\ %{}) do
    user = user_fixture()
    user_id = user.id

    {:ok, teacher} =
      attrs
      |> Enum.into(%{
        teacher_id: "some teacher id",
        designation: "some designation",
        is_af_teacher: false,
        user_id: user_id
      })
      |> Dbservice.Users.create_teacher()

    {user, teacher}
  end

  def get_user_id do
    case Users.list_student() do
      [] ->
        # No students exist, create a user first
        user = user_fixture()
        user.id

      [head | _tail] ->
        # Use existing student's user_id
        head.user_id
    end
  end

  def get_user_id_for_teacher do
    case Users.list_teacher() do
      [] ->
        # No teachers exist, create a user first
        user = user_fixture()
        user.id

      [head | _tail] ->
        # Use existing teacher's user_id
        head.user_id
    end
  end
end
