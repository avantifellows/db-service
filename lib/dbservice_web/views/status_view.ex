defmodule DbserviceWeb.StatusView do
  use DbserviceWeb, :view
  alias DbserviceWeb.StatusView

  def render("index.json", %{status: status}) do
    render_many(status, StatusView, "status.json")
  end

  def render("show.json", %{status: status}) do
    render_one(status, StatusView, "status.json")
  end

  def render("status.json", %{status: status}) do
    %{
      id: status.id,
      title: status.title
    }
  end
end
