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
      name: form_schema.name,
      attributes: form_schema.attributes
    }
  end
end
