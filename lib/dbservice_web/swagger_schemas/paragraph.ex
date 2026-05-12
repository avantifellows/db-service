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
              :string,
              "Instructional paragraph body (plain text)",
              example: "Read the following and answer the questions below."
            )
          end

          example(%{
            body: "Read the passage carefully."
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
