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
            name(:string, "Subject name")
            code(:string, "Subject Code")
            tag_id(:integer, "Tag id associated with the subject")
          end

          example(%{
            name: "Physics",
            code: "P11"
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
