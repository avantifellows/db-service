defmodule DbserviceWeb.ConceptView do
  use DbserviceWeb, :view

  def render("index.json", %{concept: concept}) do
    Enum.map(concept, &concept_json/1)
  end

  def render("show.json", %{concept: concept}) do
    concept_json(concept)
  end

  def concept_json(%{id: id, name: name, topic_id: topic_id, tag_id: tag_id}) do
    %{
      id: id,
      name: name,
      topic_id: topic_id,
      tag_id: tag_id
    }
  end
end
