defmodule Dbservice.CentresFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Centres` context.
  """

  @doc """
  Generate a centre. Creates its `group` row along with it.
  """
  def centre_fixture(attrs \\ %{}) do
    {:ok, centre} =
      attrs
      |> Enum.into(%{
        name: "some centre",
        type_code: "coe",
        category_code: "some category",
        sub_category_code: "some sub category",
        stream_codes: ["pcm"],
        is_physical: true,
        is_active: true
      })
      |> Dbservice.Centres.create_centre()

    centre
  end
end
