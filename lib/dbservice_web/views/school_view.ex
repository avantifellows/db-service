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
      medium: school.medium
    }
  end
end
