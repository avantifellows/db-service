defmodule DbserviceWeb.ChapterJSON do
  alias Dbservice.Repo

  def index(%{chapter: chapter}) do
    for(c <- chapter, do: render(c))
  end

  def show(%{chapter: chapter}) do
    render(chapter)
  end

  defp render(chapter) do
    # Preload chapter_curriculum association
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
    # If chapter_curriculum is preloaded and contains records
    if Ecto.assoc_loaded?(chapter.chapter_curriculum) && length(chapter.chapter_curriculum) > 0 do
      List.first(chapter.chapter_curriculum)
    else
      nil
    end
  end
end
