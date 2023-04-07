defmodule DbserviceWeb.SwaggerSchema.GroupType do
  @moduledoc false

  use PhoenixSwagger

  def group_type do
    %{
      GroupType:
        swagger_schema do
          title("GroupType")
          description("A Group type in application")

          properties do
            type(:string, "The type of a group")
            child_id(:integer, "The id of type")
          end

          example(%{
            type: "program",
            child_id: 24
          })
        end
    }
  end

  def group_types do
    %{
      GroupTypes:
        swagger_schema do
          title("GroupTypes")
          description("All the GroupTypes")
          type(:array)
          items(Schema.ref(:GroupType))
        end
    }
  end
end
