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
    case topic_curriculums(topic) do
      [] ->
        topic_json

      topic_curriculums ->
        Map.merge(topic_json, %{
          curriculum_ids: Enum.map(topic_curriculums, & &1.curriculum_id),
          curriculums:
            Enum.map(topic_curriculums, fn tc ->
              %{
                curriculum_id: tc.curriculum_id,
                priority: tc.priority,
                priority_text: tc.priority_text
              }
            end)
        })
    end
  end

  # Helper function to get the list of topic_curriculum records
  defp topic_curriculums(topic) do
    if Ecto.assoc_loaded?(topic.topic_curriculum) do
      topic.topic_curriculum
    else
      []
    end
  end
end
