defmodule DbserviceWeb.SwaggerSchema.Source do
  @moduledoc false

  use PhoenixSwagger

  def source do
    %{
      Source:
        swagger_schema do
          title("Source")
          description("A source in the application")

          properties do
            name(:string, "Source name")
            link(:text, "Source Link")
            tag_id(:integer, "Tag id associated with the source")
          end

          example(%{
            name: "youtube",
            link: "https://www.youtube.com/watch?v=k01UwiIvo9o",
            tag_id: 5
          })
        end
    }
  end

  def sources do
    %{
      Sources:
        swagger_schema do
          title("Sources")
          description("All sources in the application")
          type(:array)
          items(Schema.ref(:Source))
        end
    }
  end
end
