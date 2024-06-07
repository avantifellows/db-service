defmodule DbserviceWeb.SwaggerSchema.Status do
  @moduledoc false

  use PhoenixSwagger

  def status do
    %{
      Status:
        swagger_schema do
          title("Status")
          description("A status in the application")

          properties do
            title(:string, "Title of the status")
          end

          example(%{
            title: "Title of an enrollment record"
          })
        end
    }
  end

  def statuses do
    %{
      Statuses:
        swagger_schema do
          title("Statuses")
          description("All the statuses")
          type(:array)
          items(Schema.ref(:Status))
        end
    }
  end
end
