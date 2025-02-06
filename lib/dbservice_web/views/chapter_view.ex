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
