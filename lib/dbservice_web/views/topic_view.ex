defmodule DbserviceWeb.TopicView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TopicView

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
      name: default_name,
      names: topic.name,
      code: topic.code,
      chapter_id: topic.chapter_id
    }
  end

  defp get_english_language_id do
    alias Dbservice.Repo
    alias Dbservice.Languages.Language

    case Repo.get_by(Language, name: "English") do
      %Language{id: id} -> id
      nil -> nil
    end
  end

  defp get_default_name(names) when is_list(names) do
    case get_english_language_id() do
      nil ->
        case List.first(names) do
          %{"topic" => value} -> value
          _ -> nil
        end

      english_id ->
        case Enum.find(names, &(&1["lang_id"] == english_id)) do
          %{"topic" => value} ->
            value

          nil ->
            case List.first(names) do
              %{"topic" => value} -> value
              _ -> nil
            end
        end
    end
  end

  defp get_default_name(_), do: nil
end
