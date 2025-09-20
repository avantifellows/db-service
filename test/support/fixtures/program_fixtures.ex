defmodule Dbservice.ProgramsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Programs` context.
  """

  @doc """
  Generate a program.
  """
  def program_fixture(attrs \\ %{}) do
    # Create a product first since program belongs_to product
    product = Dbservice.ProductsFixtures.product_fixture()

    {:ok, program} =
      attrs
      |> Enum.into(%{
        name: "some name",
        target_outreach: 5000,
        donor: "some donor",
        state: "some state",
        model: "some model",
        is_current: true,
        product_id: product.id
      })
      |> Dbservice.Programs.create_program()

    program
  end
end
