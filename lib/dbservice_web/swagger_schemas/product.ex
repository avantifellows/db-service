defmodule DbserviceWeb.SwaggerSchema.Product do
  @moduledoc false

  use PhoenixSwagger

  def product do
    %{
      Product:
        swagger_schema do
          title("Product")
          description("A product in application")

          properties do
            name(:name, "The name of a product")
            mode(:string, "Mode of a product")
            model(:string, "Product Model")
            tech_modules(:string, "Tech Modules being used in the product")
            type(:string, "Product type")
            led_by(:string, "Who is leading the product")
            goal(:string, "Goal of the product")
            code(:string, "Product code")
          end

          example(%{
            name: "TP-Sync",
            mode: "Offline",
            model: "Live Classes",
            tech_modules: "Live Classes, Quizzes",
            type: "Test Prep",
            led_by: "AF",
            goal: "",
            code: "TP-Sync"
          })
        end
    }
  end

  def products do
    %{
      Products:
        swagger_schema do
          title("Products")
          description("All the products")
          type(:array)
          items(Schema.ref(:Product))
        end
    }
  end
end
