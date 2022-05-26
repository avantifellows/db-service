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
end
