defmodule DbserviceWeb.SwaggerSchema.School do
  @moduledoc false

  use PhoenixSwagger

  def school do
    %{
      School:
        swagger_schema do
          title("School")
          description("A school in the application")

          properties do
            code(:string, "Code")
            name(:string, "Name")
            udise_code(:string, "Udise Code")
            type(:string, "Type")
            category(:string, "Category")
            region(:string, "Region")
            state_code(:string, "State Code")
            state(:string, "State")
            district_code(:string, "District Code")
            district(:string, "District")
            block_code(:string, "Block Code")
            block_name(:string, "Block Name")
            board(:string, "Board")
            board_medium(:string, "Medium")
          end

          example(%{
            code: "872931",
            name: "Kendriya Vidyalaya - Rajori Garden",
            udise_code: "05040120901",
            type: "Open",
            category: "Government",
            region: "Urban",
            state_code: "DL",
            state: "Delhi",
            district_code: "0701",
            district: "NORTH WEST DELHI",
            block_code: "DOEAIDED",
            board: "CBSE",
            board_medium: "en"
          })
        end
    }
  end

  def schools do
    %{
      Schools:
        swagger_schema do
          title("Schools")
          description("All schools in the application")
          type(:array)
          items(Schema.ref(:School))
        end
    }
  end

  def schoolbatches do
    %{
      SchoolBatches:
        swagger_schema do
          title("School Batch")
          description("Relation between school and batch")

          properties do
            school_id(:integer, "Id of a particular school")
            batch_id(:integer, "Id of a particular batch")
          end

          example(%{
            school_id: 1,
            batch_id: 1
          })
        end
    }
  end
end
