defmodule DbserviceWeb.SwaggerSchema.Group do
  @moduledoc false

  use PhoenixSwagger

  def group do
    %{
      Group:
        swagger_schema do
          title("Group")
          description("A Group in application")

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

  def groups do
    %{
      Groups:
        swagger_schema do
          title("Groups")
          description("All the Groups")
          type(:array)
          items(Schema.ref(:Group))
        end
    }
  end
end
