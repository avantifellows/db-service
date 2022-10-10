defmodule Dbservice.UsersFixtures do
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
        state: "some state",
        whatsapp_phone: "some whatsapp phone",
        date_of_birth: ~U[2022-04-28 13:58:00Z]
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
        user_id: 142,
        group_id: 10
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
        user_id: 242,
        school_id: 316,
        program_manager_id: 97
      })
      |> Dbservice.Users.create_teacher()

    teacher
  end
end
