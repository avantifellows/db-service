defmodule DbserviceWeb.SwaggerSchema.Topic do
  @moduledoc false

  use PhoenixSwagger

  def topic do
    %{
      Topic:
        swagger_schema do
          title("Topic")
          description("A topic in the application")

          properties do
            name(
              Schema.array(:object),
              "Multilingual topic names, each with a language code and value",
              example: [
                %{lang: "en", value: "What is Matter?"},
                %{lang: "hi", value: "पदार्थ क्या है?"}
              ]
            )

            code(:string, "Topic Code")
            # This might be inferred through chapter
            grade_id(:integer, "Grade id associated with the topic")
            chapter_id(:integer, "Chapter id associated with the topic")
            # Optional: ensure this field exists in your schema
            tag_id(:integer, "Tag id associated with the topic")
          end

          example(%{
            name: [
              %{lang: "en", value: "What is Matter?"},
              %{lang: "hi", value: "पदार्थ क्या है?"}
            ],
            code: "9C01.1",
            grade_id: 1,
            chapter_id: 1,
            tag_id: 3
          })
        end
    }
  end

  def topics do
    %{
      Topics:
        swagger_schema do
          title("Topics")
          description("All topics in the application")
          type(:array)
          items(Schema.ref(:Topic))
        end
    }
  end
end
