defmodule DbserviceWeb.TopicView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TopicView
  alias Dbservice.Utils.Util

  def render("index.json", %{topic: topic}) do
    render_many(topic, TopicView, "topic.json")
  end

  def render("show.json", %{topic: topic}) do
    render_one(topic, TopicView, "topic.json")
  end

  def render("topic.json", %{topic: topic}) do
    default_name = Util.get_default_name(topic.name, :topic)

    %{
      id: topic.id,
      # For backward compatibility
      name: default_name,
      # New field with full name data
      names: topic.name,
      code: topic.code,
      chapter_id: topic.chapter_id
    }
  end
end
