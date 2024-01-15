defmodule DbserviceWeb.SwaggerSchema.Tag do
  @moduledoc false

  use PhoenixSwagger

  def tag do
    %{
      Tag:
        swagger_schema do
          title("Tag")
          description("A tag in the application")

          properties do
            name(:string, "Name of the tag")
            description(:string, "Description of the tag")
          end

          example(%{
            name: "A tag for resource",
            description: "Description of the tag"
          })
        end
    }
  end

  def tags do
    %{
      Tags:
        swagger_schema do
          title("Tags")
          description("All tags in the application")
          type(:array)
          items(Schema.ref(:Tag))
        end
    }
  end
end
