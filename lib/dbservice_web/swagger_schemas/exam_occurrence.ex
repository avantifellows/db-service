defmodule DbserviceWeb.SwaggerSchema.ExamOccurrence do
  @moduledoc false

  use PhoenixSwagger

  def exam_occurrence do
    %{
      ExamOccurrence:
        swagger_schema do
          title("ExamOccurrence")
          description("An exam occurrence in application")

          properties do
            exam_id(:integer, "The ID of the exam")
            year(:integer, "The year of the exam occurrence")
            exam_session(:integer, "The session number")
            registration_end_date(:string, "Registration end date")
            session_date(:string, "Session date")
          end

          example(%{
            exam_id: 1,
            year: 2024,
            exam_session: 1,
            registration_end_date: "2024-01-31",
            session_date: "2024-02-15"
          })
        end
    }
  end

  def exam_occurrences do
    %{
      ExamOccurrences:
        swagger_schema do
          title("ExamOccurrences")
          description("All the exam occurrences")
          type(:array)
          items(Schema.ref(:ExamOccurrence))
        end
    }
  end
end
