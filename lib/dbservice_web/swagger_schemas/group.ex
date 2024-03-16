defmodule DbserviceWeb.SwaggerSchema.Group do
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

  def groupsessions do
    %{
      GroupSessions:
        swagger_schema do
          title("Group Session")
          description("Relation between group and session")

          properties do
            group_type_id(:integer, "Id of a particular group")
            session_id(:integer, "Id of a particular group")
          end

          example(%{
            group_type_id: 1,
            session_id: 1
          })
        end
    }
  end

  def groupusers do
    %{
      GroupUsers:
        swagger_schema do
          title("Group User")
          description("Relation between group and user")

          properties do
            group_id(:integer, "Id of a particular group")
            user_id(:integer, "Id of a particular group")
            program_manager_id(:integer, "ID of a program manager")
            program_date_of_joining(:utc_datetime, "Date of joining a program")
            program_student_language(:string, "Language used in an enrolled program")
          end

          example(%{
            group_id: 1,
            user_id: 1,
            program_manager_id: 1,
            program_date_of_joining: "2020/01/06",
            program_student_language: "English"
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
