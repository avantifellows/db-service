defmodule DbserviceWeb.ResourceTopicView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceTopicView

  def render("index.json", %{resource_topic: resource_topic}) do
    render_many(resource_topic, ResourceTopicView, "resource_topic.json")
  end

  def render("show.json", %{resource_topic: resource_topic}) do
    render_one(resource_topic, ResourceTopicView, "resource_topic.json")
  end

  def render("resource_topic.json", %{resource_topic: resource_topic}) do
    %{
      id: resource_topic.id,
      resource_id: resource_topic.resource_id,
      topic_id: resource_topic.topic_id
    }
  end
end
