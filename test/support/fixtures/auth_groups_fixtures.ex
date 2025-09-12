defmodule Dbservice.AuthGroupsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.AuthGroups` context.
  """

  @doc """
  Generate an auth group.
  """
  def auth_group_fixture(attrs \\ %{}) do
    {:ok, auth_group} =
      attrs
      |> Enum.into(%{
        name: "some auth group name"
      })
      |> Dbservice.AuthGroups.create_auth_group()

    auth_group
  end
end
