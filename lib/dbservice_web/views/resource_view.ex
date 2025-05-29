defmodule DbserviceWeb.ResourceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceView
  alias DbserviceWeb.SourceView
  alias Dbservice.Repo

  def render("index.json", %{resource: resource}) do
    render_many(resource, ResourceView, "resource.json")
  end

  def render("show.json", %{resource: resource}) do
    render_one(resource, ResourceView, "resource.json")
  end

  def render("resource.json", %{resource: resource}) do
    resource = Repo.preload(resource, :source)

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
      source: render_one(resource.source, SourceView, "source.json")
    }
  end
end
