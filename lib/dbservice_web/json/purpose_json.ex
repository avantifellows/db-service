defmodule DbserviceWeb.PurposeJSON do
  def index(%{purpose: purpose}) do
    for(p <- purpose, do: data(p))
  end

  def show(%{purpose: purpose}) do
    data(purpose)
  end

  def data(purpose) do
    %{
      id: purpose.id,
      name: purpose.name,
      description: purpose.description,
      tag_id: purpose.tag_id
    }
  end
end
