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

  def groupsessions do
    %{
      GroupSessions:
        swagger_schema do
          title("Group Session")
          description("Relation between group and session")

          properties do
            group_id(:integer, "Id of a particular group")
            session_id(:integer, "Id of a particular group")
          end

          example(%{
            group_id: 1,
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
end
