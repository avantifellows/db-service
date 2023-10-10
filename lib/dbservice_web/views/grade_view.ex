defmodule DbserviceWeb.GradeView do
  use DbserviceWeb, :view
  alias DbserviceWeb.GradeView

  def render("index.json", %{grade: grade}) do
    render_many(grade, GradeView, "grade.json")
  end

  def render("show.json", %{grade: grade}) do
    render_one(grade, GradeView, "grade.json")
  end

  def render("grade.json", %{grade: grade}) do
    if is_list(grade) do
      grade |> Enum.map(&render_grade/1)
    else
      render_grade(grade)
    end
  end

  defp render_grade(grade) do
    %{
      id: grade.id,
      number: grade.number,
      tag_id: grade.tag_id
    }
  end
end
