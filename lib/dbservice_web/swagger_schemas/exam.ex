defmodule DbserviceWeb.SwaggerSchema.Exam do
  @moduledoc false

  use PhoenixSwagger

  def exam do
    %{
      Exam:
        swagger_schema do
          title("Exam")
          description("An exam in application")

          properties do
            name(:string, "The name of an exam")
            registration_deadline(:timestamp, "Deadline for registration of exam")
            date(:timestamp, "Date of the exam")
          end

          example(%{
            name: "NEET",
            registration_deadline: "2023-12-31T11:30:00Z",
            date: "2024-02-02T11:30:00Z"
          })
        end
    }
  end

  def exams do
    %{
      Exams:
        swagger_schema do
          title("Exams")
          description("All the exams")
          type(:array)
          items(Schema.ref(:Exam))
        end
    }
  end
end
