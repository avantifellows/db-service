defmodule DbserviceWeb.ChapterJSON do
  alias Dbservice.Repo

  def index(%{chapter: chapter, topic_counts: topic_counts}) do
    for(c <- chapter, do: render(c, Map.get(topic_counts, c.id, 0)))
  end

  def index(%{chapter: chapter}) do
    for(c <- chapter, do: render(c))
  end

  def show(%{chapter: chapter}) do
    render(chapter)
  end

  # topic_count is only attached on the list endpoint, where it is resolved for
  # the requested curriculum_id (see issue #633); pass nil to omit it.
  defp render(chapter, topic_count \\ nil) do
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

    maybe_put_topic_count(chapter_json, topic_count)
  end

  defp maybe_put_topic_count(chapter_json, nil), do: chapter_json

  defp maybe_put_topic_count(chapter_json, topic_count),
    do: Map.put(chapter_json, :topic_count, topic_count)

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
