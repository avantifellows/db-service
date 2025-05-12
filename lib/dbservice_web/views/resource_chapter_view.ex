defmodule DbserviceWeb.ResourceChapterView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ResourceChapterView

  def render("index.json", %{resource_chapter: resource_chapter}) do
    render_many(resource_chapter, ResourceChapterView, "resource_chapter.json")
  end

  def render("show.json", %{resource_chapter: resource_chapter}) do
    render_one(resource_chapter, ResourceChapterView, "resource_chapter.json")
  end

  def render("resource_chapter.json", %{resource_chapter: resource_chapter}) do
    %{
      id: resource_chapter.id,
      resource_id: resource_chapter.resource_id,
      chapter_id: resource_chapter.chapter_id
    }
  end
end
