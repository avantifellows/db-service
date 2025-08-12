defmodule DbserviceWeb.SwaggerSchema.Purpose do
  @moduledoc false

  use PhoenixSwagger

  def purpose do
    %{
      Purpose:
        swagger_schema do
          title("Purpose")
          description("A purpose in the application")

          properties do
            name(:string, "Purpose name")
            description(:text, "Purpose description")
          end

          example(%{
            name: "learningModule",
            description: "workbook for the program"
          })
        end
    }
  end

  def purposes do
    %{
      Purposes:
        swagger_schema do
          title("Purposes")
          description("All purposes in the application")
          type(:array)
          items(Schema.ref(:Purpose))
        end
    }
  end
end
