defmodule DbserviceWeb.ResourceConceptView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceConceptView

  def render("index.json", %{resource_concept: resource_concept}) do
    render_many(resource_concept, ResourceConceptView, "resource_concept.json")
  end

  def render("show.json", %{resource_concept: resource_concept}) do
    render_one(resource_concept, ResourceConceptView, "resource_concept.json")
  end

  def render("resource_concept.json", %{resource_concept: resource_concept}) do
    %{
      id: resource_concept.id,
      resource_id: resource_concept.resource_id,
      concept_id: resource_concept.concept_id
    }
  end
end
