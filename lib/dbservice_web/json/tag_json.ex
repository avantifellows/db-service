defmodule DbserviceWeb.TagJSON do
  def index(%{tag: tag}) do
    for(t <- tag, do: data(t))
  end

  def show(%{tag: tag}) do
    data(tag)
  end

  def data(tag) do
    %{
      id: tag.id,
      name: tag.name,
      description: tag.description
    }
  end
end
