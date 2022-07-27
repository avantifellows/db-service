defmodule DbserviceWeb.SwaggerSchema.EnrollmentRecord do
  use PhoenixSwagger

  def enrollment_record do
    %{
      EnrollmentRecord:
        swagger_schema do
          title("EnrollmentRecord")
          description("An enrollment record for the student")

          properties do
            grade(:string, "Grade")
            academic_year(:string, "Academic Year")
            is_current(:boolean, "Is current enrollment record for student")
            student_id(:integer, "Student ID that the program enrollment belongs to")
            school_id(:integer, "School ID that the program enrollment belongs to")
          end

          example(%{
            grade: "7",
            academic_year: "2022",
            is_current: true,
            student_id: 1,
            school_id: 1
          })
        end
    }
  end

  def enrollment_records do
    %{
      EnrollmentRecords:
        swagger_schema do
          title("EnrollmentRecords")
          description("All enrollment records")
          type(:array)
          items(Schema.ref(:EnrollmentRecord))
        end
    }
  end
end
