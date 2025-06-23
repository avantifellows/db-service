defmodule DbserviceWeb.ResourceJSON do
  alias DbserviceWeb.SourceJSON

  def index(%{resource: resource}) do
    for(r <- resource, do: render(r))
  end

  def show(%{resource: resource}) do
    render(resource)
  end

  def render(resource) do
    resource = Dbservice.Repo.preload(resource, :source)

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
      tag_ids: resource.tag_ids,
      teacher_id: resource.teacher_id,
      source: if(resource.source, do: SourceJSON.render(resource.source), else: nil)
    }
  end
end
