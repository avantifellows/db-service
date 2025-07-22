defmodule DbserviceWeb.SwaggerSchema.Grade do
  @moduledoc false

  use PhoenixSwagger

  def grade do
    %{
      Grade:
        swagger_schema do
          title("Grade")
          description("A grade in the application")

          properties do
            number(:integer, "Grade in school")
          end

          example(%{
            number: 12
          })
        end
    }
  end

  def grades do
    %{
      Grades:
        swagger_schema do
          title("Grades")
          description("All grades in the application")
          type(:array)
          items(Schema.ref(:Grade))
        end
    }
  end
end
