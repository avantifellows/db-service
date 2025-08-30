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
            exam_name(:string, "The name of an exam")
            counselling_body(:string, "The counselling body of the exam")
            type(:string, "The type of the exam")
          end

          example(%{
            exam_name: "NEET",
            counselling_body: "NTA",
            type: "Medical"
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
