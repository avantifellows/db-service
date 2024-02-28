defmodule DbserviceWeb.ConceptView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ConceptView

  def render("index.json", %{concept: concept}) do
    render_many(concept, ConceptView, "concept.json")
  end

  def render("show.json", %{concept: concept}) do
    render_one(concept, ConceptView, "concept.json")
  end

  def render("concept.json", %{concept: concept}) do
    %{
      id: concept.id,
      name: concept.name,
      topic_id: concept.topic_id,
      tag_id: concept.tag_id
    }
  end
end
