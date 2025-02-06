defmodule DbserviceWeb.ChapterView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ChapterView
  alias Dbservice.Repo
  alias Dbservice.Languages.Language

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
    case Repo.get_by(Language, name: "English") do
      %Language{id: id} -> id
      nil -> nil
    end
  end

  defp get_default_name(names) when is_list(names) do
    english_id = get_english_language_id()

    if english_id do
      case Enum.find(names, &(&1["lang_id"] == english_id)) do
        %{"chapter" => value} -> value
        _ -> get_first_name(names)
      end
    else
      get_first_name(names)
    end
  end

  defp get_default_name(_), do: nil

  defp get_first_name(names) do
    case List.first(names) do
      %{"chapter" => value} -> value
      _ -> nil
    end
  end
end
