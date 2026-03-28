defmodule DbserviceWeb.ChapterJSON do
  alias Dbservice.Repo

  def index(%{chapter: chapter}) do
    for(c <- chapter, do: render(c))
  end

  def show(%{chapter: chapter}) do
    render(chapter)
  end

  defp render(chapter) do
    # Preload chapter_curriculum
    chapter = Repo.preload(chapter, :chapter_curriculum)

    # Base chapter fields
    chapter_json = %{
      id: chapter.id,
      name: chapter.name,
      code: chapter.code,
      grade_id: chapter.grade_id,
      subject_id: chapter.subject_id,
      cms_status_id: chapter.cms_status_id,
      curriculums: render_curriculums(chapter.chapter_curriculum)
    }

    chapter_json
  end

  defp render_curriculums(chapter_curriculums) do
    cond do
      not Ecto.assoc_loaded?(chapter_curriculums) -> []
      Enum.empty?(chapter_curriculums) -> []
      true -> Enum.map(chapter_curriculums, &render_chapter_curriculum/1)
    end
  end

  defp render_chapter_curriculum(cc) do
    %{
      curriculum_id: cc.curriculum_id,
      priority: cc.priority,
      priority_text: cc.priority_text,
      weightage: cc.weightage
    }
  end
end
