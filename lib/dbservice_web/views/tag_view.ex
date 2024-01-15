defmodule DbserviceWeb.TagView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TagView

  def render("index.json", %{tag: tag}) do
    render_many(tag, TagView, "tag.json")
  end

  def render("show.json", %{tag: tag}) do
    render_one(tag, TagView, "tag.json")
  end

  def render("tag.json", %{tag: tag}) do
    %{
      id: tag.id,
      name: tag.name,
      description: tag.description
    }
  end
end
