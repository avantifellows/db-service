defmodule DbserviceWeb.ResourceView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceView
  alias Dbservice.Repo
  alias Dbservice.Languages.Language

  def render("index.json", %{resource: resource}) do
    render_many(resource, ResourceView, "resource.json")
  end

  def render("show.json", %{resource: resource}) do
    render_one(resource, ResourceView, "resource.json")
  end

  def render("resource.json", %{resource: resource}) do
    default_name = get_default_name(resource.name)

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

  defp get_english_language_id do
    case Repo.get_by(Language, name: "English") do
      %Language{id: id} -> id
      nil -> nil
    end
  end

  defp get_default_name(names) when is_list(names) do
    english_id = get_english_language_id()

    if english_id do
      case Enum.find(names, &(&1["lang_id"] == english_id)) do
        %{"resource" => value} -> value
        _ -> get_first_name(names)
      end
    else
      get_first_name(names)
    end
  end

  defp get_default_name(_), do: nil

  defp get_first_name(names) do
    case List.first(names) do
      %{"resource" => value} -> value
      _ -> nil
    end
  end
end
