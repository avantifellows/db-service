defmodule DbserviceWeb.ProductView do
  use DbserviceWeb, :view

  def render("index.json", %{product: products}), do: Enum.map(products, &render/1)

  def render("show.json", %{product: product}), do: render(product)

  def render(%{id: id, name: name, mode: mode, model: model, tech_modules: tech_modules, type: type, led_by: led_by, goal: goal, code: code}) do
    %{id: id, name: name, mode: mode, model: model, tech_modules: tech_modules, type: type, led_by: led_by, goal: goal, code: code}
  end

end
