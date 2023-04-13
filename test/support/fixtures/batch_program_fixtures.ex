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
        batch_id: 1,
        program_id: 1
      })
      |> Dbservice.BatchPrograms.create_batch_program()

    batch
  end
end
