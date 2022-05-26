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
        medium: "some medium",
        name: "some name"
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
        is_current: true
      })
      |> Dbservice.Schools.create_enrollment_record()

    enrollment_record
  end
end
