defmodule DbserviceWeb.SourceView do
  use DbserviceWeb, :view

  def render("index.json", %{source: source}) do
    Enum.map(source, &source_json/1)
  end

  def render("show.json", %{source: source}) do
    source_json(source)
  end

  def source_json(source) do
    %{
      id: source.id,
      name: source.name,
      link: source.link,
      tag_id: source.tag_id
    }
  end
end
