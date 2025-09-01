defmodule Dbservice.ProductsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Products` context.
  """

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    {:ok, product} =
      attrs
      |> Enum.into(%{
        name: "some product name",
        code: "PROD001",
        mode: "online",
        model: "standard",
        tech_modules: "module1,module2",
        type: "course",
        led_by: "instructor",
        goal: "learning goal",
        is_active: true
      })
      |> Dbservice.Products.create_product()

    product
  end
end
