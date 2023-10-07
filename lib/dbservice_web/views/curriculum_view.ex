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
    if is_list(curriculum) do
      curriculum |> Enum.map(&render_curriculum/1)
    else
      render_curriculum(curriculum)
    end
  end

  defp render_curriculum(curriculum) do
    %{
      id: curriculum.id,
      name: curriculum.name,
      code: curriculum.code,
      tag_id: curriculum.tag_id
    }
  end
end
