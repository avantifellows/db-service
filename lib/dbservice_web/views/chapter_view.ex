defmodule DbserviceWeb.ChapterView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ChapterView
  alias Dbservice.Repo

  def render("index.json", %{chapter: chapter}) do
    render_many(chapter, ChapterView, "chapter.json")
  end

  def render("show.json", %{chapter: chapter}) do
    render_one(chapter, ChapterView, "chapter.json")
  end

  def render("chapter.json", %{chapter: chapter}) do
    chapter = Repo.preload(chapter, :chapter_curriculum)

    # Start with the base chapter fields
    chapter_json = %{
      id: chapter.id,
      name: chapter.name,
      code: chapter.code,
      grade_id: chapter.grade_id,
      subject_id: chapter.subject_id
    }

    # Add chapter_curriculum fields if they exist
    case get_chapter_curriculum(chapter) do
      nil ->
        chapter_json

      chapter_curriculum ->
        Map.merge(chapter_json, %{
          priority: chapter_curriculum.priority,
          priority_text: chapter_curriculum.priority_text,
          weightage: chapter_curriculum.weightage,
          curriculum_id: chapter_curriculum.curriculum_id
        })
    end
  end

  # Helper function to get the chapter_curriculum
  defp get_chapter_curriculum(chapter) do
    # If chapter_curriculums is preloaded, take the first one
    cond do
      Ecto.assoc_loaded?(chapter.chapter_curriculum) && length(chapter.chapter_curriculum) > 0 ->
        List.first(chapter.chapter_curriculum)

      true ->
        nil
    end
  end
end
