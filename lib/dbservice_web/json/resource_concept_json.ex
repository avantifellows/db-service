defmodule DbserviceWeb.ResourceConceptJSON do
  def index(%{resource_concept: resource_concept}) do
    for(rc <- resource_concept, do: render(rc))
  end

  def show(%{resource_concept: resource_concept}) do
    render(resource_concept)
  end

  defp render(resource_concept) do
    %{
      id: resource_concept.id,
      resource_id: resource_concept.resource_id,
      concept_id: resource_concept.concept_id
    }
  end
end
