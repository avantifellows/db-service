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
            name(
              Schema.array(:object),
              "Multilingual concept names, each with a language code and value",
              example: [
                %{lang: "en", value: "Coulomb's Law"},
                %{lang: "hi", value: "कूलॉम्ब का नियम"}
              ]
            )

            topic_id(:integer, "Topic id associated with the concept")
          end

          example(%{
            name: [
              %{lang: "en", value: "Coulomb's Law"},
              %{lang: "hi", value: "कूलॉम्ब का नियम"}
            ],
            topic_id: 5
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
