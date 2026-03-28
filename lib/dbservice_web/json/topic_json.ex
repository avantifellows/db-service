defmodule DbserviceWeb.TopicJSON do
  alias Dbservice.Repo

  def index(%{topic: topic}) do
    for(t <- topic, do: render(t))
  end

  def show(%{topic: topic}) do
    render(topic)
  end

  defp render(topic) do
    # Preload topic_curriculum association
    topic = Repo.preload(topic, :topic_curriculum)

    # Start with the base topic fields
    topic_json = %{
      id: topic.id,
      name: topic.name,
      code: topic.code,
      chapter_id: topic.chapter_id,
      cms_status_id: topic.cms_status_id
    }

    # Add topic_curriculum fields if they exist
    case get_topic_curriculum(topic) do
      nil ->
        topic_json

      topic_curriculum ->
        Map.merge(topic_json, %{
          priority: topic_curriculum.priority,
          priority_text: topic_curriculum.priority_text,
          curriculum_id: topic_curriculum.curriculum_id
        })
    end
  end

  # Helper function to get the topic_curriculum
  defp get_topic_curriculum(topic) do
    # If topic_curriculum is preloaded and contains records
    if Ecto.assoc_loaded?(topic.topic_curriculum) && not Enum.empty?(topic.topic_curriculum) do
      List.first(topic.topic_curriculum)
    else
      nil
    end
  end
end
