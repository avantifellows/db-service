defmodule DbserviceWeb.PurposeView do
  use DbserviceWeb, :view
  alias DbserviceWeb.PurposeView

  def render("index.json", %{purpose: purpose}) do
    render_many(purpose, PurposeView, "purpose.json")
  end

  def render("show.json", %{purpose: purpose}) do
    render_one(purpose, PurposeView, "purpose.json")
  end

  def render("purpose.json", %{purpose: purpose}) do
    %{
      id: purpose.id,
      name: purpose.name,
      description: purpose.description,
      tag_id: purpose.tag_id
    }
  end
end
