defmodule DbserviceWeb.SwaggerSchema.Group do
  @moduledoc false

  use PhoenixSwagger

  def group do
    %{
      Group:
        swagger_schema do
          title("Group")
          description("A group in the application")

          properties do
            name(:string, "Name of a group")
            parent_id(:integer, "ID of a parent")
            type(:string, "Type of a group")
            program_type(:string, "Type of a program")
            program_sub_type(:string, "Sub-type of a program")
            program_mode(:string, "Mode of a program")
            program_start_date(:date, "Starting date of a program")
            program_target_outreach(:integer, "Target outreach for a particular program")
            program_products_used(:string, "Products used in a program")
            program_donor(:string, "Donor of a program")
            batch_contact_hours_per_week(:integer, "Contact hours for a batch in a week")
            group_input_schema(:map, "Input schema")
            group_locale(:string, "The configured locale for the group")
            group_locale_data(:map, "Meta data about locale settings for the group")
            program_model(:string, "Program Model")
            group_id(:string, "ID of the group")
          end

          example(%{
            name: "Abhinav Singh",
            parent_id: 1,
            type: "program",
            program_type: "",
            program_sub_type: "",
            program_mode: "Offline",
            program_start_date: "2020/02/03",
            program_target_outreach: 1000,
            program_products_used: "",
            program_donor: "",
            program_state: "Delhi",
            batch_contact_hours_per_week: 48,
            group_input_schema: %{},
            group_locale: "hi",
            group_locale_data: %{
              "hi" => %{
                "title" => "सत्र के लिए पंजीकरण करें"
              },
              "en" => %{
                "title" => "Register for session"
              }
            },
            program_model: "Live Classes",
            group_id: "2243345211",
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

  def groups do
    %{
      Groups:
        swagger_schema do
          title("Groups")
          description("All the groups")
          type(:array)
          items(Schema.ref(:Group))
        end
    }
  end
end
