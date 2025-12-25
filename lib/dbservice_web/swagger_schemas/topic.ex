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
              "Multilingual topic names. Each object should contain 'lang_code' and 'topic' keys",
              example: [
                %{lang_code: "en", topic: "What is Matter?"},
                %{lang_code: "hi", topic: "पदार्थ क्या है?"}
              ]
            )

            code(:string, "Topic Code")
            chapter_id(:integer, "Chapter id associated with the topic")
            cms_status(:string, "Status name from cms_status table. Also accepts cms_status_id.")
            cms_status_id(:integer, "cms_status.id value to set status directly")
          end

          example(%{
            name: [
              %{lang_code: "en", topic: "What is Matter?"},
              %{lang_code: "hi", topic: "पदार्थ क्या है?"}
            ],
            code: "9C01.1",
            chapter_id: 1,
            cms_status: "archived"
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
