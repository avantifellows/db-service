defmodule DbserviceWeb.TopicView do
  use DbserviceWeb, :view

  def render("index.json", %{topic: topic}) do
    Enum.map(topic, &topic_json/1)
  end

  def render("show.json", %{topic: topic}) do
    topic_json(topic)
  end

  def topic_json(%{__meta__: _} = topic) do
    %{
      id: topic.id,
      name: topic.name,
      code: topic.code,
      grade_id: topic.grade_id,
      chapter_id: topic.chapter_id,
      tag_id: topic.tag_id
    }
  end
end
