defmodule DbserviceWeb.ChapterJSON do
  def index(%{chapter: chapter}) do
    for(c <- chapter, do: render(c))
  end

  def show(%{chapter: chapter}) do
    render(chapter)
  end

  defp render(chapter) do
    %{
      id: chapter.id,
      name: chapter.name,
      code: chapter.code,
      grade_ids: chapter.grade_ids,
      subject_id: chapter.subject_id,
      tag_id: chapter.tag_id,
      curriculum_id: chapter.curriculum_id
    }
  end
end
