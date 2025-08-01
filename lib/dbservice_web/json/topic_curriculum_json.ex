defmodule DbserviceWeb.TopicCurriculumJSON do
  def index(%{topic_curriculum: topic_curriculum}) do
    for(tc <- topic_curriculum, do: render(tc))
  end

  def show(%{topic_curriculum: topic_curriculum}) do
    render(topic_curriculum)
  end

  defp render(topic_curriculum) do
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
