defmodule DbserviceWeb.ConceptJSON do
  def index(%{concept: concept}) do
    for(c <- concept, do: render(c))
  end

  def show(%{concept: concept}) do
    render(concept)
  end

  def render(concept) do
    %{
      id: concept.id,
      name: concept.name,
      topic_id: concept.topic_id
    }
  end
end
