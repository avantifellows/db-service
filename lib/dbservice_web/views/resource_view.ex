defmodule DbserviceWeb.ResourceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceView
  alias Dbservice.Resources.ResourceTopic
  alias Dbservice.Resources.ResourceChapter
  alias Dbservice.Repo
  import Ecto.Query

  def render("index.json", %{resource: resource}) do
    render_many(resource, ResourceView, "resource.json")
  end

  def render("show.json", %{resource: resource}) do
    render_one(resource, ResourceView, "resource.json")
  end

  def render("resource.json", %{resource: resource}) do
    topic_id =
      Repo.one(
        from rt in ResourceTopic,
          where: rt.resource_id == ^resource.id,
          select: rt.topic_id,
          limit: 1
      )

    chapter_id =
      Repo.one(
        from rt in ResourceChapter,
          where: rt.resource_id == ^resource.id,
          select: rt.chapter_id,
          limit: 1
      )

    base_map = %{
      id: resource.id,
      name: resource.name,
      type: resource.type,
      type_params: resource.type_params,
      subtype: resource.subtype,
      source: resource.source,
      code: resource.code,
      purpose_ids: resource.purpose_ids,
      tag_ids: resource.tag_ids,
      skill_ids: resource.skill_ids,
      learning_objective_ids: resource.learning_objective_ids,
      teacher_id: resource.teacher_id,
      topic_id: topic_id,
      chapter_id: chapter_id
    }

    if Map.has_key?(resource, :meta_data) do
      Map.put(base_map, :meta_data, resource.meta_data)
    else
      base_map
    end
  end
end
