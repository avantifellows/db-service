defmodule DbserviceWeb.SwaggerSchema.Batch do
  @moduledoc false

  use PhoenixSwagger

  def batch do
    %{
      Batch:
        swagger_schema do
          title("Batch")
          description("A batch in application")

          properties do
            name(:string, "The name of a batch")
            contact_hours_per_week(:integer, "Contact hours per week of a batch")
            batch_id(:string, "The id of a batch")
            parent_id(:string, "The id of a parent batch")
            af_medium(:stream, "AF medium")
            metadata(:map, "Metadata of a batch")
          end

          example(%{
            name: "Delhi-12-NEET",
            contact_hours_per_week: 48,
            batch_id: "DelhiStudents_11_Photon_Eng_23_001",
            parent_id: 1,
            af_medium: "medical",
            metadata: %{"key" => "value"}
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
