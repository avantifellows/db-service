defmodule Dbservice.GradesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Grades` context.
  """

  @doc """
  Generate a grade.
  """
  def grade_fixture(attrs \\ %{}) do
    {:ok, grade} =
      attrs
      |> Enum.into(%{
        number: 10
      })
      |> Dbservice.Grades.create_grade()

    grade
  end
end
