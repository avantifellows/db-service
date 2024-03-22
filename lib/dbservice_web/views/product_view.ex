defmodule DbserviceWeb.ProductView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ProductView

  def render("index.json", %{product: product}) do
    render_many(product, ProductView, "product.json")
  end

  def render("show.json", %{product: product}) do
    render_one(product, ProductView, "product.json")
  end

  def render("product.json", %{product: product}) do
    %{
      id: product.id,
      name: product.name,
      mode: product.mode,
      model: product.model,
      tech_modules: product.tech_modules,
      type: product.type,
      led_by: product.led_by,
      goal: product.goal,
      code: product.code
    }
  end
end
