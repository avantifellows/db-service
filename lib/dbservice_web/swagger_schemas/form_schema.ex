defmodule DbserviceWeb.SwaggerSchema.FormSchema do
  @moduledoc false

  use PhoenixSwagger

  def form_schema do
    %{
      FormSchema:
        swagger_schema do
          title("FormSchema")
          description("A form schema in the application")

          properties do
            name(:string, "Name of a form schema")
            attributes(:map, "Attribute data for form schema")
          end

          example(%{
            name: "Registration",
            data: %{
              "label" => "First Name"
            },
          })
        end
    }
  end

  def form_schemas do
    %{
      FormSchemas:
        swagger_schema do
          title("FormSchemas")
          description("All the form schemas")
          type(:array)
          items(Schema.ref(:FormSchema))
        end
    }
  end
end
