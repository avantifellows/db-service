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
            type(:string, "Type of a program")
            sub_type(:string, "Sub-type of a program")
            mode(:string, "Mode of a program")
            start_date(:date, "Starting date of a program")
            target_outreach(:integer, "Target outreach for a particular program")
            products_used(:string, "Products used in a program")
            donor(:string, "Donor of a program")
            model(:string, "Program Model")
            group_id(:integer, "ID of the group")
          end

          example(%{
            name: "Delhi-Govt",
            type: "Test Prep",
            sub_type: "AF-Led",
            mode: "Offline",
            start_date: "2020/02/03",
            target_outreach: 1000,
            products_used: "",
            donor: "Infosys, MSDF, Sofina",
            state: "Delhi",
            model: "Live Classes",
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
