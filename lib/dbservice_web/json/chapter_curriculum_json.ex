defmodule DbserviceWeb.ChapterCurriculumJSON do
  def index(%{chapter_curriculum: chapter_curriculum}) do
    for(cc <- chapter_curriculum, do: render(cc))
  end

  def show(%{chapter_curriculum: chapter_curriculum}) do
    render(chapter_curriculum)
  end

  defp render(chapter_curriculum) do
    %{
      id: chapter_curriculum.id,
      chapter_id: chapter_curriculum.chapter_id,
      curriculum_id: chapter_curriculum.curriculum_id,
      priority: chapter_curriculum.priority,
      priority_text: chapter_curriculum.priority_text,
      weightage: chapter_curriculum.weightage
    }
  end
end
