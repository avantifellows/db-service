defmodule DbserviceWeb.FormSchemaJSON do
  def index(%{form_schema: form_schema}) do
    %{data: for(schema <- form_schema, do: data(schema))}
  end

  def show(%{form_schema: form_schema}) do
    %{data: data(form_schema)}
  end

  defp data(form_schema) do
    %{
      id: form_schema.id,
      name: form_schema.name,
      attributes: form_schema.attributes,
      meta_data: form_schema.meta_data
    }
  end
end
