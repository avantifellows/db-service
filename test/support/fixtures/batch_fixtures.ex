defmodule Dbservice.BatchesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.batch` context.
  """

  @doc """
  Generate a batch.
  """
  def batch_fixture(attrs \\ %{}) do
    {:ok, batch} =
      attrs
      |> Enum.into(%{
        name: "some name",
        contact_hours_per_week: Enum.random(20..48)
      })
      |> Dbservice.Batches.create_batch()

    batch
  end
end
