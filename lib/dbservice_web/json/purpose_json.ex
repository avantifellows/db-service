defmodule DbserviceWeb.PurposeJSON do
  def index(%{purpose: purpose}) do
    for(p <- purpose, do: render(p))
  end

  def show(%{purpose: purpose}) do
    render(purpose)
  end

  def render(purpose) do
    %{
      id: purpose.id,
      name: purpose.name,
      description: purpose.description,
      tag_id: purpose.tag_id
    }
  end
end
