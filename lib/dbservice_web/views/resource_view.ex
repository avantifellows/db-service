defmodule DbserviceWeb.ResourceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceView
  alias Dbservice.Utils.Util

  def render("index.json", %{resource: resource}) do
    render_many(resource, ResourceView, "resource.json")
  end

  def render("show.json", %{resource: resource}) do
    render_one(resource, ResourceView, "resource.json")
  end

  def render("resource.json", %{resource: resource}) do
    default_name = Util.get_default_name(resource.name, :resource)

    %{
      id: resource.id,
      name: default_name,
      names: resource.name,
      type: resource.type,
      type_params: resource.type_params,
      subtype: resource.subtype,
      source: resource.source,
      code: resource.code,
      purpose_ids: resource.purpose_ids,
      tag_ids: resource.tag_ids,
      skill_ids: resource.skill_ids,
      learning_objective_ids: resource.learning_objective_ids,
      teacher_id: resource.teacher_id
    }
  end
end
