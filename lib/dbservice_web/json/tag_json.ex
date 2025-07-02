defmodule DbserviceWeb.TagJSON do
  def index(%{tag: tag}) do
    for(t <- tag, do: render(t))
  end

  def show(%{tag: tag}) do
    render(tag)
  end

  def render(tag) do
    %{
      id: tag.id,
      name: tag.name,
      description: tag.description
    }
  end
end
