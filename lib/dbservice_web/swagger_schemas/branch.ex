defmodule DbserviceWeb.SwaggerSchema.Branch do
  @moduledoc false

  use PhoenixSwagger

  def branch do
    %{
      Branch:
        swagger_schema do
          title("Branch")
          description("A branch/course in the application")

          properties do
            branch_id(:string, "The unique branch ID")
            parent_branch_id(:string, "Parent branch ID")
            name(:string, "Branch name")
            duration(:integer, "Duration in years")
          end

          example(%{
            branch_id: "CSE",
            parent_branch_id: nil,
            name: "Computer Science Engineering",
            duration: 4
          })
        end
    }
  end

  def branches do
    %{
      Branches:
        swagger_schema do
          title("Branches")
          description("All the branches")
          type(:array)
          items(Schema.ref(:Branch))
        end
    }
  end

  def branch_names do
    %{
      BranchNames:
        swagger_schema do
          title("BranchNames")
          description("Branch names only — lightweight list for dropdowns")
          type(:array)

          example([
            %{id: 1, branch_id: "CSE", name: "Computer Science Engineering"}
          ])
        end
    }
  end
end
