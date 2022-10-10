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
        name: "some name",
        type: "group",
        program_type: "some program type",
        program_sub_type: "some program subtype",
        program_mode: "some program mode",
        program_start_date: ~U[2022-04-28 13:58:00Z],
        program_target_outreach: Enum.random(3000..9999),
        program_donor: "some program donor",
        program_state: "some program state",
        batch_contact_hours_per_week: Enum.random(20..48),
        group_input_schema: %{},
        group_locale: "some locale",
        group_locale_data: %{}
      })
      |> Dbservice.Groups.create_group()

    group
  end
end
