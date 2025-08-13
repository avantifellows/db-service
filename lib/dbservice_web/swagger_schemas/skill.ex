defmodule DbserviceWeb.SwaggerSchema.Skill do
  @moduledoc false

  use PhoenixSwagger

  def skill do
    %{
      Skill:
        swagger_schema do
          title("Skill")
          description("A Skill in application")

          properties do
            name(:string, "name of Skill")
          end

          example(%{
            name: "English"
          })
        end
    }
  end

  def skills do
    %{
      Skills:
        swagger_schema do
          title("Skills")
          description("All the Skills")
          type(:array)
          items(Schema.ref(:Skill))
        end
    }
  end
end
