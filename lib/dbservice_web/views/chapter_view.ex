defmodule DbserviceWeb.ChapterView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ChapterView

  def render("index.json", %{chapter: chapter}) do
    render_many(chapter, ChapterView, "chapter.json")
  end

  def render("show.json", %{chapter: chapter}) do
    render_one(chapter, ChapterView, "chapter.json")
  end

  def render("chapter.json", %{chapter: chapter}) do
    default_name = get_default_name(chapter.name)

    %{
      id: chapter.id,
      name: default_name,
      names: chapter.name,
      code: chapter.code,
      grade_id: chapter.grade_id,
      subject_id: chapter.subject_id,
      # tag_id: chapter.tag_id,
      curriculum_id: chapter.curriculum_id
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
          %{"subject" => value} -> value
          _ -> nil
        end

      english_id ->
        case Enum.find(names, &(&1["lang_id"] == english_id)) do
          %{"subject" => value} ->
            value

          nil ->
            case List.first(names) do
              %{"subject" => value} -> value
              _ -> nil
            end
        end
    end
  end

  defp get_default_name(_), do: nil
end
