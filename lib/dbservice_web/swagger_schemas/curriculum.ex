defmodule DbserviceWeb.SwaggerSchema.Curriculum do
  @moduledoc false

  use PhoenixSwagger

  def curriculum do
    %{
      Curriculum:
        swagger_schema do
          title("Curriculum")
          description("A curriculum in the application")

          properties do
            name(:string, "Name of the curriculum")
            code(:string, "Code of the curriculum")
          end

          example(%{
            name: "Sankalp",
            code: "S-10"
          })
        end
    }
  end

  def curriculums do
    %{
      Curriculums:
        swagger_schema do
          title("Curriculums")
          description("All Curriculums in the application")
          type(:array)
          items(Schema.ref(:Curriculum))
        end
    }
  end
end
