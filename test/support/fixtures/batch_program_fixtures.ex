defmodule Dbservice.BatchProgramsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.batch_program` context.
  """

  @doc """
  Generate a batch program.
  """
  def batch_program_fixture(attrs \\ %{}) do
    {:ok, batch} =
      attrs
      |> Enum.into(%{
        batch_id: Enum.random(1..100),
        program_id: Enum.random(1..100)
      })
      |> Dbservice.BatchPrograms.create_batch_program()

    batch
  end
end
