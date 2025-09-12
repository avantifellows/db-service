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
        gender_type: "some gender type",
        af_school_category: "some af school category",
        region: "some region",
        state_code: "some state code",
        state: "some state",
        district_code: "some district code",
        district: "some district",
        block_code: "some block code",
        block_name: "some block name",
        board: "some board",
        user_id: nil
      })
      |> Dbservice.Schools.create_school()

    school
  end
end
