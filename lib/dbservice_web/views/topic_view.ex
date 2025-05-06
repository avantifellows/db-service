defmodule DbserviceWeb.TopicView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TopicView
  alias Dbservice.Repo

  def render("index.json", %{topic: topic}) do
    render_many(topic, TopicView, "topic.json")
  end

  def render("show.json", %{topic: topic}) do
    render_one(topic, TopicView, "topic.json")
  end

  def render("topic.json", %{topic: topic}) do
    topic = Repo.preload(topic, :topic_curriculum)

    topic_json = %{
      id: topic.id,
      name: topic.name,
      code: topic.code,
      chapter_id: topic.chapter_id
    }

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
    if Ecto.assoc_loaded?(topic.topic_curriculum) && length(topic.topic_curriculum) > 0 do
      List.first(topic.topic_curriculum)
    else
      nil
    end
  end
end
