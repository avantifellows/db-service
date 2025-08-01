defmodule DbserviceWeb.ResourceChapterJSON do
  def index(%{resource_chapter: resource_chapter}) do
    for(rc <- resource_chapter, do: render(rc))
  end

  def show(%{resource_chapter: resource_chapter}) do
    render(resource_chapter)
  end

  defp render(resource_chapter) do
    %{
      id: resource_chapter.id,
      resource_id: resource_chapter.resource_id,
      chapter_id: resource_chapter.chapter_id
    }
  end
end
