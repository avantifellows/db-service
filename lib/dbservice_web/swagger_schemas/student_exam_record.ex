defmodule DbserviceWeb.SwaggerSchema.StudentExamRecord do
  @moduledoc false

  use PhoenixSwagger

  def student_exam_record do
    %{
      StudentExamRecord:
        swagger_schema do
          title("Student Exam Record")
          description("A record of a student's exam details")

          properties do
            id(:integer, "Record ID", required: true)
            student_id(:integer, "Student ID", required: true)
            exam_id(:integer, "Exam ID", required: true)
            marks(:integer, "Marks obtained", required: true)
          end

          example(%{
            id: 1,
            student_id: 123,
            exam_id: 456,
            marks: 90
          })
        end
    }
  end

  def student_exam_records do
    %{
      StudentExamRecords:
        swagger_schema do
          title("List of Student Exam Records")
          description("A collection of student exam records")

          properties do
            records(array(:StudentExamRecord), "List of student exam records")
          end

          example(%{
            records: [
              %{
                id: 1,
                student_id: 123,
                exam_id: 456,
                marks: 90
              },
              %{
                id: 2,
                student_id: 124,
                exam_id: 457,
                marks: 85
              }
            ]
          })
        end
    }
  end
end
