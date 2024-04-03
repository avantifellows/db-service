defmodule DbserviceWeb.SwaggerSchema.Concept do
  @moduledoc false

  use PhoenixSwagger

  def concept do
    %{
      Concept:
        swagger_schema do
          title("Concept")
          description("A concept in the application")

          properties do
            name(:string, "Concept name")
            topic_id(:integer, "Topic id associated with the concept")
            tag_id(:integer, "Tag id associated with the concept")
          end

          example(%{
            name: "Coulomb's Law",
            topic_id: 5,
            tag_id: 6
          })
        end
    }
  end

  def concepts do
    %{
      Concepts:
        swagger_schema do
          title("Concepts")
          description("All concepts in the application")
          type(:array)
          items(Schema.ref(:Concept))
        end
    }
  end
end
