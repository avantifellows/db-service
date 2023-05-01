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
            id: 54,
            type: "program",
            child_id: %{
              donor: "YES",
              group_id: 29,
              id: 24,
              mode: "Offline",
              model: "Live Classes",
              name: "Mrs. Stefanie Goldner",
              product_used: "One",
              start_date: "2016-11-18",
              state: "UTTARAKHAND",
              sub_type: "High",
              target_outreach: 4743,
              type: "Competitive"
            }
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
