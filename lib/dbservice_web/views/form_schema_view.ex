defmodule DbserviceWeb.FormSchemaView do
  use DbserviceWeb, :view
  alias DbserviceWeb.FormSchemaView

  def render("index.json", %{form_schema: form_schema}) do
    render_many(form_schema, FormSchemaView, "form_schema.json")
  end

  def render("show.json", %{form_schema: form_schema}) do
    render_one(form_schema, FormSchemaView, "form_schema.json")
  end

  def render("form_schema.json", %{form_schema: form_schema}) do
    %{
      id: form_schema.id,
      name: form_schema.name,
      attributes: form_schema.attributes,
      meta_data: form_schema.meta_data
    }
  end
end
