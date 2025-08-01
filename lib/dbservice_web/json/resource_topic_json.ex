defmodule DbserviceWeb.ResourceTopicJSON do
  def index(%{resource_topic: resource_topic}) do
    for(rt <- resource_topic, do: render(rt))
  end

  def show(%{resource_topic: resource_topic}) do
    render(resource_topic)
  end

  defp render(resource_topic) do
    %{
      id: resource_topic.id,
      resource_id: resource_topic.resource_id,
      topic_id: resource_topic.topic_id
    }
  end
end
