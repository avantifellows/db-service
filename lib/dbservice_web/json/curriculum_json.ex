defmodule DbserviceWeb.CurriculumJSON do
  def index(%{curriculum: curriculum}) do
    for(c <- curriculum, do: render(c))
  end

  def show(%{curriculum: curriculum}) do
    render(curriculum)
  end

  defp render(curriculum) do
    %{
      id: curriculum.id,
      name: curriculum.name,
      code: curriculum.code
    }
  end
end
