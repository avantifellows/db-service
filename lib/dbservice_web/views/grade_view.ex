defmodule DbserviceWeb.GradeView do
  use DbserviceWeb, :view

  def render("index.json", %{grade: grades}) do
    Enum.map(grades, &grade_json/1)
  end

  def render("show.json", %{grade: grade}) do
    grade_json(grade)
  end

  def grade_json(grade) do
    render("grade.json", %{grade: grade})


  end
end
