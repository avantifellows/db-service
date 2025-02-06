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
    find_name_by_language(names, english_id)
  end

  defp get_default_name(_), do: nil

  defp find_name_by_language(names, english_id) do
    cond do
      english_id != nil ->
        find_english_name(names, english_id)
      true ->
        get_first_name(names)
    end
  end

  defp find_english_name(names, english_id) do
    case Enum.find(names, &(&1["lang_id"] == english_id)) do
      %{"topic" => value} -> value
      _ -> get_first_name(names)
    end
  end

  defp get_first_name(names) do
    case List.first(names) do
      %{"topic" => value} -> value
      _ -> nil
    end
  end
end
