defmodule DbserviceWeb.SwaggerSchema.AcademicMentorshipMapping do
  @moduledoc false

  use PhoenixSwagger

  def academic_mentorship_mapping do
    %{
      AcademicMentorshipMapping:
        swagger_schema do
          title("AcademicMentorshipMapping")
          description("A mentor-mentee mapping for academic mentorship")

          properties do
            id(:integer, "Mapping ID")
            mentor_id(:integer, "The user_permission ID of the mentor")
            mentee_id(:integer, "The user ID of the mentee")
            academic_year(:string, "Academic year (e.g. 2025-2026)")
            created_by(:string, "Email of the user who created this mapping")
            updated_by(:string, "Email of the user who last modified this mapping")
            deleted_at(:string, "Soft-delete timestamp (null if active)")
            inserted_at(:string, "Creation timestamp")
            updated_at(:string, "Last update timestamp")
          end

          example(%{
            id: 1,
            mentor_id: 42,
            mentee_id: 100,
            academic_year: "2025-2026",
            created_by: "admin@example.com",
            updated_by: nil,
            deleted_at: nil,
            inserted_at: "2025-06-01T12:00:00",
            updated_at: "2025-06-01T12:00:00"
          })
        end
    }
  end

  def academic_mentorship_mappings do
    %{
      AcademicMentorshipMappings:
        swagger_schema do
          title("AcademicMentorshipMappings")
          description("List of academic mentorship mappings")

          properties do
            mappings(Schema.array(:AcademicMentorshipMapping), "List of mappings")
          end
        end
    }
  end
end
