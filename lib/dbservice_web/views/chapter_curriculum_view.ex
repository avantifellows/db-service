defmodule DbserviceWeb.ChapterCurriculumView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ChapterCurriculumView

  def render("index.json", %{chapter_curriculum: chapter_curriculum}) do
    render_many(chapter_curriculum, ChapterCurriculumView, "chapter_curriculum.json")
  end

  def render("show.json", %{chapter_curriculum: chapter_curriculum}) do
    render_one(chapter_curriculum, ChapterCurriculumView, "chapter_curriculum.json")
  end

  def render("chapter_curriculum.json", %{chapter_curriculum: chapter_curriculum}) do
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
