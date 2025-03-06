defmodule DbserviceWeb.ResourceCurriculumView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceCurriculumView

  def render("index.json", %{resource_curriculum: resource_curriculum}) do
    render_many(resource_curriculum, ResourceCurriculumView, "resource_curriculum.json")
  end

  def render("show.json", %{resource_curriculum: resource_curriculum}) do
    render_one(resource_curriculum, ResourceCurriculumView, "resource_curriculum.json")
  end

  def render("resource_curriculum.json", %{resource_curriculum: resource_curriculum}) do
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
