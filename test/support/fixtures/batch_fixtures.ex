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
        name: "some batch name",
        contact_hours_per_week: 30,
        batch_id: "BATCH001",
        parent_id: nil,
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-06-01],
        program_id: nil,
        auth_group_id: nil,
        af_medium: "online"
      })
      |> Dbservice.Batches.create_batch()

    batch
  end
end
