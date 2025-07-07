defmodule DbserviceWeb.SourceJSON do
  def index(%{source: source}) do
    for(s <- source, do: render(s))
  end

  def show(%{source: source}) do
    render(source)
  end

  def render(source) do
    %{
      id: source.id,
      name: source.name,
      link: source.link,
      tag_id: source.tag_id
    }
  end
end
