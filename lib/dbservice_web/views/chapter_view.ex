defmodule DbserviceWeb.ChapterView do
  use DbserviceWeb, :view

  def render("index.json", %{chapter: chapter}) do
    Enum.map(chapter, &chapter_json/1)
  end

  def render("show.json", %{chapter: chapter}) do
    chapter_json(chapter)
  end

  def chapter_json(%{id: id, name: name, code: code, grade_id: grade_id, subject_id: subject_id, tag_id: tag_id, curriculum_id: curriculum_id}) do
    %{
      id: id,
      name: name,
      code: code,
      grade_id: grade_id,
      subject_id: subject_id,
      tag_id: tag_id,
      curriculum_id: curriculum_id
    }
  end
end
