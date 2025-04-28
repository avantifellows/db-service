defmodule DbserviceWeb.PurposeView do
  use DbserviceWeb, :view

  def render("index.json", %{purpose: purposes}) do
    Enum.map(purposes, &purpose_json/1)
  end

  def render("show.json", %{purpose: purpose}) do
    purpose_json(purpose)
  end

  def render("purpose.json", %{purpose: purpose}) do
    %{
      id: purpose.id,
      name: purpose.name,
      description: purpose.description,
      tag_id: purpose.tag_id
    }
  end

  defp purpose_json(%{__meta__: _} = purpose) do
    %{
      id: purpose.id,
      name: purpose.name,
      description: purpose.description,
      tag_id: purpose.tag_id
    }
  end
end
