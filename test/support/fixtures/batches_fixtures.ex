defmodule Dbservice.BatchesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Batches` context.
  """

  @doc """
  Generate a batch.
  """
  def batch_fixture(attrs \\ %{}) do
    {:ok, batch} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> Dbservice.Batches.create_batch()

    batch
  end
end
