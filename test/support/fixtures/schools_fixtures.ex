defmodule Dbservice.SchoolsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Schools` context.
  """

  @doc """
  Generate a school.
  """
  def school_fixture(attrs \\ %{}) do
    {:ok, school} =
      attrs
      |> Enum.into(%{
        code: "some code",
        name: "some name",
        udise_code: "some udise code",
        type: "some type",
        category: "some category",
        region: "some region",
        state_code: "some state code",
        state: "some state",
        district_code: "some district code",
        district: "some district",
        block_code: "some block code",
        block_name: "some block name",
        board: "some board",
        board_medium: "some board medium"
      })
      |> Dbservice.Schools.create_school()

    school
  end

  @doc """
  Generate a enrollment_record.
  """
  def enrollment_record_fixture(attrs \\ %{}) do
    {:ok, enrollment_record} =
      attrs
      |> Enum.into(%{
        academic_year: "some academic_year",
        grade: "some grade",
        is_current: true,
        board_medium: "some board medium",
        date_of_enrollment: ~U[2022-04-28 13:58:00Z],
        student_id: 92,
        school_id: 323
      })
      |> Dbservice.Schools.create_enrollment_record()

    enrollment_record
  end
end
