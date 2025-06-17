defmodule DbserviceWeb.TopicJSON do
  def index(%{topic: topic}) do
    for(t <- topic, do: data(t))
  end

  def show(%{topic: topic}) do
    data(topic)
  end

  def data(topic) do
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
