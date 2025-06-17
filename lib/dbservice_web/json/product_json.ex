defmodule DbserviceWeb.ProductJSON do
  def index(%{product: product}) do
    for(p <- product, do: data(p))
  end

  def show(%{product: product}) do
    data(product)
  end

  def data(product) do
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
