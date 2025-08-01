defmodule DbserviceWeb.ResourceCurriculumJSON do
  def index(%{resource_curriculum: resource_curriculum}) do
    for(rc <- resource_curriculum, do: render(rc))
  end

  def show(%{resource_curriculum: resource_curriculum}) do
    render(resource_curriculum)
  end

  defp render(resource_curriculum) do
    %{
      id: resource_curriculum.id,
      resource_id: resource_curriculum.resource_id,
      curriculum_id: resource_curriculum.curriculum_id,
      grade_id: resource_curriculum.grade_id,
      subject_id: resource_curriculum.subject_id,
      difficulty_level: resource_curriculum.difficulty_level
    }
  end
end
