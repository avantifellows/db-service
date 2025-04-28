defmodule DbserviceWeb.CurriculumView do
  use DbserviceWeb, :view

  def render("index.json", %{curriculum: curriculum}) do
    Enum.map(curriculum, &curriculum_json/1)
  end

  def render("show.json", %{curriculum: curriculum}) do
    curriculum_json(curriculum)
  end

  def curriculum_json(%{id: id, name: name, code: code, tag_id: tag_id}) do
    %{
      id: id,
      name: name,
      code: code,
      tag_id: tag_id
    }
  end
end
