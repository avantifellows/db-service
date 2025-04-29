defmodule DbserviceWeb.FormSchemaView do
  use DbserviceWeb, :view

  def render("index.json", %{form_schema: form_schemas}) do
    Enum.map(form_schemas, &form_schema_json/1)
  end

  def render("show.json", %{form_schema: form_schema}) do
    form_schema_json(form_schema)
  end

  def form_schema_json(%{id: id, name: name, attributes: attributes, meta_data: meta_data}) do
    %{
      id: id,
      name: name,
      attributes: attributes,
      meta_data: meta_data
    }
  end
end
