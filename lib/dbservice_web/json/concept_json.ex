defmodule DbserviceWeb.ConceptJSON do
  def index(%{concept: concept}) do
    for(c <- concept, do: render(c))
  end

  def show(%{concept: concept}) do
    render(concept)
  end

  defp render(concept) do
    %{
      id: concept.id,
      name: concept.name,
      topic_id: concept.topic_id,
      tag_id: concept.tag_id
    }
  end
end
