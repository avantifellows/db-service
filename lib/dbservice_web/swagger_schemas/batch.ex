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
        end,
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
        end,
    }
  end

  def user_ids do
    %{
      UserIds:
        swagger_schema do
          properties do
            user_ids(:array, "List of user ids")
          end

          example(%{
            user_ids: [1, 2]
          })
        end,
    }
  end

  def session_ids do
    %{
      SessionIds:
        swagger_schema do
          properties do
            session_ids(:array, "List of session ids")
          end

          example(%{
            session_ids: [1, 2]
          })
        end
    }
  end
end
