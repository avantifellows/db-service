defmodule DbserviceWeb.SwaggerSchema.Language do
  @moduledoc false

  use PhoenixSwagger

  def language do
    %{
      Language:
        swagger_schema do
          title("Language")
          description("A Language in application")

          properties do
            name(:string, "name of language")
          end

          example(%{
            name: "English"
          })
        end
    }
  end

  def languages do
    %{
      Languages:
        swagger_schema do
          title("Languages")
          description("All the languages")
          type(:array)
          items(Schema.ref(:Language))
        end
    }
  end
end
