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
            exam_id(:string, "The unique ID of the exam")
            name(:string, "The name of an exam")
            cutoff_id(:string, "The cutoff ID for the exam")
            conducting_body(:string, "The conducting body of the exam")
            registration_deadline(:timestamp, "Deadline for registration of exam")
            date(:timestamp, "Date of the exam")
            cutoff(:object, "Cutoff details")
          end

          example(%{
            exam_id: "EXAM123",
            name: "NEET",
            cutoff_id: "CUTOFF456",
            conducting_body: "NTA",
            registration_deadline: "2023-12-31T11:30:00Z",
            date: "2024-02-02T11:30:00Z",
            cutoff: %{category: "General", value: 600}
          })
        end
    }
  end

  def exams do
    %{
      Exams:
        swagger_schema do
          title("Exam")
          description("All the exams")
          type(:array)
          items(Schema.ref(:Exam))
        end
    }
  end
end
