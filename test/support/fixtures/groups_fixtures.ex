defmodule Dbservice.GroupsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Groups` context.
  """

  @doc """
  Generate a group.
  """
  def group_fixture(attrs \\ %{}) do
    {:ok, group} =
      attrs
      |> Enum.into(%{
        type: "some type",
        child_id: 1
      })
      |> Dbservice.Groups.create_group()

    group
  end
end
