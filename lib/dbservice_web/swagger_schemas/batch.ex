defmodule DbserviceWeb.SwaggerSchema.Batch do
  use PhoenixSwagger

  def batch do
    %{
      Batch:
        swagger_schema do
          title("Batch")
          description("A batch of students")

          properties do
            name(:string, "Batch name")
          end

          example(%{
            name: "Kendriya Vidyalaya - Class 12th"
          })
        end
    }
  end

  def batches do
    %{
      Batches:
        swagger_schema do
          title("Batches")
          description("All the batches")
          type(:array)
          items(Schema.ref(:Batch))
        end
    }
  end
end
