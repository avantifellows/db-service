defmodule DbserviceWeb.SourceJSON do
  def index(%{source: source}) do
    for(s <- source, do: data(s))
  end

  def show(%{source: source}) do
    data(source)
  end

  def data(source) do
    %{
      id: source.id,
      name: source.name,
      link: source.link,
      tag_id: source.tag_id
    }
  end
end
