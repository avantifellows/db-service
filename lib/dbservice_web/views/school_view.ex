defmodule DbserviceWeb.SchoolView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SchoolView

  def render("index.json", %{school: school}) do
    render_many(school, SchoolView, "school.json")
  end

  def render("show.json", %{school: school}) do
    render_one(school, SchoolView, "school.json")
  end

  def render("school.json", %{school: school}) do
    %{
      id: school.id,
      code: school.code,
      name: school.name,
      udise_code: school.udise_code,
      type: school.type,
      category: school.category,
      region: school.region,
      state_code: school.state_code,
      state: school.state,
      district_code: school.district_code,
      district: school.district,
      block_code: school.block_code,
      block_name: school.block_name,
      board: school.board,
      board_medium: school.board_medium
    }
  end
end
