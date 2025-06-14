defmodule DbserviceWeb.ConceptJSON do
  def index(%{concept: concept}) do
    %{data: for(c <- concept, do: data(c))}
  end

  def show(%{concept: concept}) do
    %{data: data(concept)}
  end

  defp data(concept) do
    %{
      id: concept.id,
      name: concept.name,
      topic_id: concept.topic_id,
      tag_id: concept.tag_id
    }
  end
end
