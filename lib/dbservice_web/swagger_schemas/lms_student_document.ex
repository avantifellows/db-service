defmodule DbserviceWeb.SwaggerSchema.LmsStudentDocument do
  @moduledoc false

  use PhoenixSwagger

  def lms_student_document do
    %{
      LmsStudentDocument:
        swagger_schema do
          title("LmsStudentDocument")
          description("A document (e.g. research consent) tagged to a student")

          properties do
            id(:integer, "Document ID")
            student_id(:integer, "Student ID", required: true)
            document_type(:string, "Document type", required: true)
            pages(:array, "Array of {s3_key, page_number, mime_type, byte_size}", required: true)
            metadata(:object, "Per-type extensible fields")
            uploaded_by(:string, "Email of the uploading user", required: true)
            deleted_at(:string, "Soft-delete timestamp", format: "ISO-8601")
            inserted_at(:string, "Created timestamp", format: "ISO-8601")
            updated_at(:string, "Updated timestamp", format: "ISO-8601")
          end

          example(%{
            id: 1,
            student_id: 12_345,
            document_type: "research_consent",
            pages: [
              %{
                s3_key: "students/12345/research_consent/abc-def/page-1.jpg",
                page_number: 1,
                mime_type: "image/jpeg",
                byte_size: 245_678
              }
            ],
            metadata: %{consent_version: "v1"},
            uploaded_by: "teacher@avantifellows.org"
          })
        end
    }
  end

  def lms_student_documents do
    %{
      LmsStudentDocuments:
        swagger_schema do
          title("LmsStudentDocuments")
          description("A collection of student documents")
          type(:array)
          items(Schema.ref(:LmsStudentDocument))
        end
    }
  end
end
