defmodule DbserviceWeb.TagView do
  use DbserviceWeb, :view

  def render("index.json", %{tag: tag}) do
    Enum.map(tag, &tag_json/1)
  end

  def render("show.json", %{tag: tag}) do
    tag_json(tag)
  end

  def tag_json(%{__meta__: _} = tag) do
    %{
      id: tag.id,
      name: tag.name,
      description: tag.description
    }
  end
end
