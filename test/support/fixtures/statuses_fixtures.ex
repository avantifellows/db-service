defmodule Dbservice.StatusesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Statuses` context.
  """

  @doc """
  Generate a status.
  """
  def status_fixture(attrs \\ %{}) do
    {:ok, status} =
      attrs
      |> Enum.into(%{
        title: :registered
      })
      |> Dbservice.Statuses.create_status()

    status
  end
end
