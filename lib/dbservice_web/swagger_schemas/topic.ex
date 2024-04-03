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
            name(:string, "Topic name")
            code(:string, "Topic Code")
            grade_id(:integer, "Grade id associated with the topic")
            chapter_id(:integer, "Chapter id associated with the topic")
            tag_id(:integer, "Tag id associated with the topic")
          end

          example(%{
            name: "What is Matter?",
            code: "9C01.1",
            grade_id: 1,
            subject_id: 1,
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
