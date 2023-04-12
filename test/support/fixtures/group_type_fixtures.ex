defmodule Dbservice.GroupTypesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.group_type` context.
  """

  @doc """
  Generate a group_type.
  """
  def group_type_fixture(attrs \\ %{}) do
    {:ok, group_type} =
      attrs
      |> Enum.into(%{
        type: "some type",
        child_id: Enum.random(1..100)
      })
      |> Dbservice.GroupTypes.create_group_type()

      group_type
  end
end
