defmodule DbserviceWeb.ProductJSON do
  def index(%{product: product}) do
    for(p <- product, do: render(p))
  end

  def show(%{product: product}) do
    render(product)
  end

  def render(product) do
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
