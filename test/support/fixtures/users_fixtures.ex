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
        state: "some state"
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
        uuid: "some uuid"
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
        subject: "some subject"
      })
      |> Dbservice.Users.create_teacher()

    teacher
  end
end
