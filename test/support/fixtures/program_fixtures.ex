defmodule Dbservice.ProgramsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.program` context.
  """

  @doc """
  Generate a program.
  """
  def program_fixture(attrs \\ %{}) do
    {:ok, program} =
      attrs
      |> Enum.into(%{
        name: "some name",
        type: "some type",
        sub_type: "some subtype",
        mode: "some mode",
        start_date: ~D[2022-04-28],
        target_outreach: Enum.random(3000..9999),
        product_used: "some product used",
        donor: "some donor",
        state: "some state",
        model: "some model"
      })
      |> Dbservice.Programs.create_program()

    program
  end
end
