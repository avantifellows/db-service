defmodule DbserviceWeb.SourceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SourceView

  def render("index.json", %{source: source}) do
    render_many(source, SourceView, "source.json")
  end

  def render("show.json", %{source: source}) do
    render_one(source, SourceView, "source.json")
  end

  def render("source.json", %{source: source}) do
    %{
      id: source.id,
      name: source.name,
      link: source.link,
      tag_id: source.tag_id
    }
  end
end
