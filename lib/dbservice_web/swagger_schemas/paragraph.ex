defmodule DbserviceWeb.SwaggerSchema.Paragraph do
  @moduledoc false

  use PhoenixSwagger

  def paragraph do
    %{
      Paragraph:
        swagger_schema do
          title("Paragraph")

          description(
            "Instructional paragraph text; problems are linked via problem_lang.paragraph_id " <>
              "(each problem_lang row carries lang_id)"
          )

          properties do
            body(
              Schema.array(:object),
              "Multilingual paragraph body, each entry with lang and value",
              example: [
                %{lang: "en", value: "Read the following and answer the questions below."},
                %{lang: "hi", value: "निम्नलिखित पढ़ें और नीचे दिए प्रश्नों के उत्तर दें।"}
              ]
            )
          end

          example(%{
            body: [
              %{lang: "en", value: "Read the passage carefully."},
              %{lang: "hi", value: "पैराग्राफ ध्यान से पढ़ें।"}
            ]
          })
        end
    }
  end

  def paragraphs do
    %{
      Paragraphs:
        swagger_schema do
          title("Paragraphs")
          description("All paragraph records")
          type(:array)
          items(Schema.ref(:Paragraph))
        end
    }
  end
end
