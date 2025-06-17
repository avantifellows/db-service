defmodule DbserviceWeb.CurriculumJSON do
  def index(%{curriculum: curriculum}) do
    for(c <- curriculum, do: data(c))
  end

  def show(%{curriculum: curriculum}) do
    data(curriculum)
  end

  defp data(curriculum) do
    %{
      id: curriculum.id,
      name: curriculum.name,
      code: curriculum.code,
      tag_id: curriculum.tag_id
    }
  end
end
