defmodule DbserviceWeb.StatusView do
  use DbserviceWeb, :view

  def render("index.json", %{status: status}) do
    Enum.map(status, &status_json/1)
  end

  def render("show.json", %{status: status}) do
    status_json(status)
  end

  def status_json(%{id: id, title: title}) do
    %{id: id, title: title}
  end
end
