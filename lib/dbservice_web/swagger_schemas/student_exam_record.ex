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
            application_number(:string, "Application number on the exam portal", required: true)
            application_password(:string, "Password for the exam portal")
            date(:string, "Date of the exam", format: "date")
            score(:number, "Score obtained")
            percentile(:number, "Percentile obtained")
            all_india_rank(:integer, "All India rank")
            category_rank(:integer, "Rank within the student's category")

            sessions_applied(
              Schema.array(:integer),
              "Session numbers the student applied for, for an exam that runs more than once a year"
            )

            exam_email(:string, "Email ID the student registered for the exam with")
            exam_phone(:string, "Contact number the student registered for the exam with")
            exam_roll_no(:string, "Roll number issued for the exam")
            exam_year(:integer, "Year in which the exam took place")
          end

          example(%{
            id: 1,
            student_id: 123,
            exam_id: 456,
            application_number: "JEE2026001234",
            application_password: "s3cret",
            date: "2026-01-24",
            score: 212.0,
            percentile: 98.76,
            all_india_rank: 15_432,
            category_rank: 2301,
            sessions_applied: [1, 2],
            exam_email: "student@example.com",
            exam_phone: "9876543210",
            exam_roll_no: "JE26010234",
            exam_year: 2026
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
          type(:array)
          items(Schema.ref(:StudentExamRecord))
        end
    }
  end
end
