defmodule DbserviceWeb.BatchView do
  use DbserviceWeb, :view
  alias DbserviceWeb.BatchView

  def render("index.json", %{batch: batch}) do
    %{data: render_many(batch, BatchView, "batch.json")}
  end

  def render("show.json", %{batch: batch}) do
    %{data: render_one(batch, BatchView, "batch.json")}
  end

  def render("batch.json", %{batch: batch}) do
    %{
      id: batch.id,
      name: batch.name
    }
  end
end
