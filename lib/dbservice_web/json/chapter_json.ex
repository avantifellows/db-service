defmodule DbserviceWeb.ChapterJSON do
  def index(%{chapter: chapter}) do
    %{data: for(c <- chapter, do: data(c))}
  end

  def show(%{chapter: chapter}) do
    %{data: data(chapter)}
  end

  defp data(chapter) do
    %{
      id: chapter.id,
      name: chapter.name,
      code: chapter.code,
      grade_id: chapter.grade_id,
      subject_id: chapter.subject_id,
      tag_id: chapter.tag_id,
      curriculum_id: chapter.curriculum_id
    }
  end
end
