defmodule DbserviceWeb.SwaggerSchema.School do
  use PhoenixSwagger

  def school do
    %{
      School:
        swagger_schema do
          title("School")
          description("A school in the application")

          properties do
            code(:string, "Code")
            name(:string, "Name")
            medium(:string, "Medium")
          end

          example(%{
            code: "872931",
            name: "Kendriya Vidyalaya - Rajori Garden",
            medium: "en"
          })
        end
    }
  end

  def schools do
    %{
      Schools:
        swagger_schema do
          title("Schools")
          description("All schools in the application")
          type(:array)
          items(Schema.ref(:School))
        end
    }
  end
end
