defmodule DbserviceWeb.SwaggerSchema.Teacher do
  @moduledoc false

  use PhoenixSwagger

  def teacher do
    %{
      Teacher:
        swagger_schema do
          title("Teacher")
          description("A teacher in the application")

          properties do
            designation(:string, "Designation")
            subject(:string, "Core subject")
            grade(:string, "Grade")
            user_id(:integer, "User ID for the teacher")
            school_id(:integer, "School ID for the teacher")
            program_manager_id(:integer, "Program manager user ID for the teacher")
            uuid(:string, "UUID for the teacher")
          end

          example(%{
            designation: "Vice Principal",
            subject: "Mats",
            grade: "12",
            user_id: 1,
            school_id: 2,
            program_manager_id: 3,
            uuid: "3bc6b53e7bbbc883b9ab"
          })
        end
    }
  end

  def teachers do
    %{
      Teachers:
        swagger_schema do
          title("Teachers")
          description("All teachers in the application")
          type(:array)
          items(Schema.ref(:Teacher))
        end
    }
  end
end
