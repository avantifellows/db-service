defmodule DbserviceWeb.GradeJSON do
  def index(%{grade: grade}) do
    for(g <- grade, do: render(g))
  end

  def show(%{grade: grade}) do
    render(grade)
  end

  def render(grade) do
    %{
      id: grade.id,
      number: grade.number
    }
  end
end
