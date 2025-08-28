defmodule DbserviceWeb.SwaggerSchema.TopicCurriculum do
  @moduledoc false

  use PhoenixSwagger

  def topic_curriculum do
    %{
      TopicCurriculum:
        swagger_schema do
          title("Topic Curriculum")
          description("Relationship between topic and curriculum with priority settings")

          properties do
            topic_id(:integer, "Id of the topic")
            curriculum_id(:integer, "Id of the curriculum")
            priority(:integer, "Priority order of the curriculum in the topic")
            priority_text(:string, "Text description of the priority")
            inserted_at(:string, "Creation timestamp")
            updated_at(:string, "Update timestamp")
          end

          example(%{
            topic_id: 1,
            curriculum_id: 1,
            priority: 1,
            priority_text: "High",
            inserted_at: "2024-02-05T10:00:00Z",
            updated_at: "2024-02-05T10:00:00Z"
          })
        end
    }
  end

  def topic_curriculums do
    %{
      TopicCurriculums:
        swagger_schema do
          title("Topic Curriculum")
          description("All topic_curriculums in the application")
          type(:array)
          items(Schema.ref(:TopicCurriculum))
        end
    }
  end
end
