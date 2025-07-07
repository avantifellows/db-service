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
            exam_id(:string, "The unique identifier for the exam", required: true)
            name(:string, "The name of an exam")
            registration_deadline(:timestamp, "Deadline for registration of exam")
            date(:timestamp, "Date of the exam")
            conductingbody(:string, "The organization conducting the exam")
            cutoff(:map, "Cutoff details for the exam")
          end

          example(%{
            exam_id: "NEET_2024",
            name: "NEET",
            registration_deadline: "2023-12-31T11:30:00Z",
            date: "2024-02-02T11:30:00Z",
            conductingbody: "National Testing Agency",
            cutoff: %{general: 720, obc: 700, sc: 650, st: 600}
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
