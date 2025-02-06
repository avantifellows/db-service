defmodule DbserviceWeb.TopicView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TopicView
  alias Dbservice.Repo
  alias Dbservice.Languages.Language

  def render("index.json", %{topic: topic}) do
    render_many(topic, TopicView, "topic.json")
  end

  def render("show.json", %{topic: topic}) do
    render_one(topic, TopicView, "topic.json")
  end

  def render("topic.json", %{topic: topic}) do
    default_name = get_default_name(topic.name)

    %{
      id: topic.id,
      # For backward compatibility
      name: default_name,
      # New field with full name data
      names: topic.name,
      code: topic.code,
      chapter_id: topic.chapter_id
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
        %{"topic" => value} -> value
        _ -> get_first_name(names)
      end
    else
      get_first_name(names)
    end
  end

  defp get_default_name(_), do: nil

  defp get_first_name(names) do
    case List.first(names) do
      %{"topic" => value} -> value
      _ -> nil
    end
  end
end
