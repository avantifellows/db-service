defmodule DbserviceWeb.SwaggerSchema.Program do
  @moduledoc false

  use PhoenixSwagger

  def program do
    %{
      Program:
        swagger_schema do
          title("Program")
          description("A program in application")

          properties do
            name(:name, "The name of a program")
            program_type(:string, "Type of a program")
            program_sub_type(:string, "Sub-type of a program")
            program_mode(:string, "Mode of a program")
            program_start_date(:date, "Starting date of a program")
            program_target_outreach(:integer, "Target outreach for a particular program")
            program_products_used(:string, "Products used in a program")
            program_donor(:string, "Donor of a program")
            program_model(:string, "Program Model")
            group_id(:integer, "ID of the group")
          end

          example(%{
            name: "Delhi-Govt",
            program_type: "Test Prep",
            program_sub_type: "AF-Led",
            program_mode: "Offline",
            program_start_date: "2020/02/03",
            program_target_outreach: 1000,
            program_products_used: "",
            program_donor: "Infosys, MSDF, Sofina",
            program_state: "Delhi",
            program_model: "Live Classes",
            group_id: 1
          })
        end
    }
  end

  def programs do
    %{
      Programs:
        swagger_schema do
          title("Programs")
          description("All the programs")
          type(:array)
          items(Schema.ref(:Program))
        end
    }
  end
end
