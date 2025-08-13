defmodule DbserviceWeb.SwaggerSchema.ChapterCurriculum do
  @moduledoc false

  use PhoenixSwagger

  def chapter_curriculum do
    %{
      ChapterCurriculum:
        swagger_schema do
          title("Chapter Curriculum")
          description("Relationship between chapter and curriculum with priority settings")

          properties do
            chapter_id(:integer, "Id of the chapter")
            curriculum_id(:integer, "Id of the curriculum")
            priority(:integer, "Priority order of the curriculum in the chapter")
            priority_text(:string, "Text description of the priority")
            weightage(:integer, "Weightage of the curriculum in the chapter")
            inserted_at(:string, "Creation timestamp")
            updated_at(:string, "Update timestamp")
          end

          example(%{
            chapter_id: 1,
            curriculum_id: 1,
            priority: 1,
            priority_text: "High",
            weightage: 30,
            inserted_at: "2024-02-05T10:00:00Z",
            updated_at: "2024-02-05T10:00:00Z"
          })
        end
    }
  end

  def chapter_curriculums do
    %{
      ChapterCurriculums:
        swagger_schema do
          title("Chapter Curriculum")
          description("All chapter_curriculums in the application")
          type(:array)
          items(Schema.ref(:ChapterCurriculum))
        end
    }
  end
end
