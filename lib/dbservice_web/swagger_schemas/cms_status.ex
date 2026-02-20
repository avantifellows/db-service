defmodule DbserviceWeb.SwaggerSchema.CmsStatus do
  @moduledoc false

  use PhoenixSwagger

  def cms_status do
    %{
      CmsStatus:
        swagger_schema do
          title("CmsStatus")
          description("A cms_status in the application")

          properties do
            name(:string, "Name of the cms_status")
          end

          example(%{
            name: "archived"
          })
        end
    }
  end

  def cms_statuses do
    %{
      CmsStatuses:
        swagger_schema do
          title("CmsStatuses")
          description("All the cms_statuses")
          type(:array)
          items(Schema.ref(:CmsStatus))
        end
    }
  end
end
