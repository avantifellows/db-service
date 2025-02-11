defmodule DbserviceWeb.CurriculumView do
  use DbserviceWeb, :view
  alias DbserviceWeb.CurriculumView

  def render("index.json", %{curriculum: curriculum}) do
    render_many(curriculum, CurriculumView, "curriculum.json")
  end

  def render("show.json", %{curriculum: curriculum}) do
    render_one(curriculum, CurriculumView, "curriculum.json")
  end

  def render("curriculum.json", %{curriculum: curriculum}) do
    %{
      id: curriculum.id,
      name: curriculum.name,
      code: curriculum.code
    }
  end
end
