defmodule DbserviceWeb.SwaggerSchema.BatchProgram do
  @moduledoc false

  use PhoenixSwagger

  def batch_program do
    %{
      BatchProgram:
        swagger_schema do
          title("BatchProgram")
          description("A mapping between batch and program")

          properties do
            batch_id(:integer, "The id of the batch")
            program_id(:integer, "The id of the program")
          end

          example(%{
            batch_id: 1,
            program_id: 1
          })
        end
    }
  end

  def batch_programs do
    %{
      BatchPrograms:
        swagger_schema do
          title("BatchPrograms")
          description("All batch and program mappings")
          type(:array)
          items(Schema.ref(:BatchProgram))
        end
    }
  end
end
