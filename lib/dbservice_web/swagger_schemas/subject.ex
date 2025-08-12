defmodule DbserviceWeb.SwaggerSchema.Subject do
  @moduledoc false

  use PhoenixSwagger

  def subject do
    %{
      Subject:
        swagger_schema do
          title("Subject")
          description("A subject in the application")

          properties do
            name(
              Schema.array(:object),
              "Multilingual subject names. Each object should contain 'lang_code' and 'subject' keys",
              example: [
                %{lang_code: "en", subject: "Physics"},
                %{lang_code: "hi", subject: "भौतिकी"}
              ]
            )

            code(:string, "Subject Code")
            parent_id(:integer, "Parent subject ID")
          end

          example(%{
            name: [
              %{lang_code: "en", subject: "Physics"},
              %{lang_code: "hi", subject: "भौतिकी"}
            ],
            code: "P11",
            parent_id: 1
          })
        end
    }
  end

  def subjects do
    %{
      Subjects:
        swagger_schema do
          title("Subjects")
          description("All subjects in the application")
          type(:array)
          items(Schema.ref(:Subject))
        end
    }
  end
end
