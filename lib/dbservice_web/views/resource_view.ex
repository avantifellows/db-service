defmodule DbserviceWeb.ResourceView do
  use DbserviceWeb, :view

  def render("index.json", %{resource: resources}) do
    Enum.map(resources, &resource_json/1)
  end

  def render("show.json", %{resource: resource}) do
    resource_json(resource)
  end

  def resource_json(%{__meta__: _meta} = resource) do
    %{
      id: resource.id,
      name: resource.name,
      type: resource.type,
      type_params: resource.type_params,
      difficulty_level: resource.difficulty_level,
      curriculum_id: resource.curriculum_id,
      chapter_id: resource.chapter_id,
      topic_id: resource.topic_id,
      source_id: resource.source_id,
      purpose_id: resource.purpose_id,
      concept_id: resource.concept_id,
      learning_objective_id: resource.learning_objective_id,
      tag_id: resource.tag_id,
      teacher_id: resource.teacher_id
    }
  end
end
