defmodule DbserviceWeb.GradeJSON do
  def index(%{grade: grade}) do
    %{data: for(g <- grade, do: data(g))}
  end

  def show(%{grade: grade}) do
    %{data: data(grade)}
  end

  def data(grade) do
    %{
      id: grade.id,
      number: grade.number,
      tag_id: grade.tag_id
    }
  end
end
