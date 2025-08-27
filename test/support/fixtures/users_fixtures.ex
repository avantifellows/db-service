defmodule Dbservice.UsersFixtures do
  alias Dbservice.Users
  alias Dbservice.SubjectsFixtures

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
        email: "some.email@example.com",
        phone: "9456591269",
        gender: "male",
        address: "some address",
        city: "some city",
        district: "some district",
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
        student_id: "some_student_id",
        father_name: "some father name",
        father_phone: "some father phone",
        father_education_level: "some father education level",
        father_profession: "some father profession",
        mother_name: "some mother name",
        mother_phone: "some mother phone",
        mother_education_level: "some mother education level",
        mother_profession: "some mother profession",
        guardian_name: "some guardian name",
        guardian_relation: "some guardian relation",
        guardian_phone: "some guardian phone",
        guardian_education_level: "some guardian education level",
        guardian_profession: "some guardian profession",
        category: "some category",
        has_category_certificate: false,
        stream: "some stream",
        physically_handicapped: false,
        physically_handicapped_certificate: "some certificate",
        annual_family_income: "some income",
        monthly_family_income: "some income",
        time_of_device_availability: "some time",
        has_internet_access: "no",
        primary_smartphone_owner: "some owner",
        primary_smartphone_owner_profession: "some profession",
        number_of_smartphones: "1",
        family_type: "nuclear",
        number_of_four_wheelers: "0",
        number_of_two_wheelers: "1",
        has_air_conditioner: false,
        goes_for_tuition_or_other_coaching: "no",
        know_about_avanti: "no",
        percentage_in_grade_10_science: "85",
        percentage_in_grade_10_math: "90",
        percentage_in_grade_10_english: "88",
        grade_10_marksheet: "some marksheet",
        photo: "some photo",
        planned_competitive_exams: [],
        status: "active",
        board_stream: "science",
        school_medium: "english",
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
    subject = SubjectsFixtures.subject_fixture()
    subject_id = subject.id

    {:ok, teacher} =
      attrs
      |> Enum.into(%{
        designation: "some designation",
        teacher_id: "some_teacher_id",
        is_af_teacher: false,
        user_id: user_id,
        subject_id: subject_id
      })
      |> Dbservice.Users.create_teacher()

    {user, subject, teacher}
  end
end
