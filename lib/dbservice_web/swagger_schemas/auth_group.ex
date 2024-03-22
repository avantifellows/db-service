defmodule DbserviceWeb.SwaggerSchema.AuthGroup do
  @moduledoc false

  use PhoenixSwagger

  def auth_group do
    %{
      AuthGroup:
        swagger_schema do
          title("AuthGroup")
          description("An auth-group in the application")

          properties do
            name(:string, "Name of the auth group")
            input_schema(:map, "Input schema")
            locale(:string, "The configured locale for the auth-group")
            locale_data(:map, "Meta data about locale settings for the auth-group")
          end

          example(%{
            name: "DelhiStudents",
            input_schema: %{},
            locale: "hi",
            locale_data: %{
              "hi" => %{
                "title" => "सत्र के लिए पंजीकरण करें"
              },
              "en" => %{
                "title" => "Register for session"
              }
            }
          })
        end
    }
  end

  def auth_groups do
    %{
      AuthGroups:
        swagger_schema do
          title("AuthGroups")
          description("All the auth-groups")
          type(:array)
          items(Schema.ref(:AuthGroup))
        end
    }
  end
end
