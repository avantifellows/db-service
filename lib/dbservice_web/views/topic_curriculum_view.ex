defmodule DbserviceWeb.TopicCurriculumView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TopicCurriculumView

  def render("index.json", %{topic_curriculum: topic_curriculum}) do
    render_many(topic_curriculum, TopicCurriculumView, "topic_curriculum.json")
  end

  def render("show.json", %{topic_curriculum: topic_curriculum}) do
    render_one(topic_curriculum, TopicCurriculumView, "topic_curriculum.json")
  end

  def render("topic_curriculum.json", %{topic_curriculum: topic_curriculum}) do
    %{
      id: topic_curriculum.id,
      topic_id: topic_curriculum.topic_id,
      curriculum_id: topic_curriculum.curriculum_id,
      priority: topic_curriculum.priority,
      priority_text: topic_curriculum.priority_text,
      weightage: topic_curriculum.weightage
    }
  end
end
