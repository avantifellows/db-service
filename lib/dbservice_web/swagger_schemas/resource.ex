defmodule DbserviceWeb.SwaggerSchema.Resource do
  @moduledoc false

  use PhoenixSwagger

  def resource do
    %{
      Resource:
        swagger_schema do
          title("Resource")
          description("A resource in the application")

          properties do
            name(:string, "Resource name")
            type(:string, "Resource type")
            type_params(:map, "Parameters of the resource type")
            subtype(:string, "Sub-type of a resource")
            source(:string, "Source of a resource")
            code(:string, "Code of a resource")
            purpose_ids(:array, "Purpose ids associated with the resource")
            learning_objective_ids(:array, "Learning objective ids associated with the resource")
            tag_ids(:array, "Tag ids associated with the resource")
            teacher_id(:integer, "Teacher id associated with the resource")
          end

          example(%{
            name: "1. 9C01 Introduction - हमारे आस पास के पदार्थ | Matter in our Surroundings",
            type: "video",
            type_params: %{
              "duration" => "45 minutes"
            },
            subtype: "lecture",
            source: "youtube",
            code: "RES_001",
            purpose_ids: [1, 2, 3],
            learning_objective_ids: [4, 5, 6],
            tag_ids: [5, 7, 9],
            teacher_id: 1
          })
        end
    }
  end

  def resources do
    %{
      Resources:
        swagger_schema do
          title("Resources")
          description("All resources in the application")
          type(:array)
          items(Schema.ref(:Resource))
        end
    }
  end

  def resource_curriculum do
    %{
      ResourceCurriculum:
        swagger_schema do
          title("ResourceCurriculum")
          description("A resource-curriculum in the application")

          properties do
            resource_id(:integer, "Resource id associated with the resource")
            curriculum_id(:integer, "Curriculum id associated with the resource")
            difficulty_level(:string, "Difficulty level of a resource")
          end

          example(%{
            resource_id: 1,
            curriculum_id: 1,
            difficulty_level: "medium"
          })
        end
    }
  end

  def resource_curriculums do
    %{
      ResourceCurriculums:
        swagger_schema do
          title("ResourceCurriculums")
          description("All resources-curriculums in the application")
          type(:array)
          items(Schema.ref(:ResourceCurriculum))
        end
    }
  end

  def resource_chapter do
    %{
      ResourceChapter:
        swagger_schema do
          title("ResourceChapter")
          description("A resource-chapter in the application")

          properties do
            resource_id(:integer, "Resource id associated with the resource")
            chapter_id(:integer, "Chapter id associated with the resource")
          end

          example(%{
            resource_id: 1,
            chapter_id: 1
          })
        end
    }
  end

  def resource_chapters do
    %{
      ResourceChapters:
        swagger_schema do
          title("ResourceChapters")
          description("All resources-chapters in the application")
          type(:array)
          items(Schema.ref(:ResourceCurriculum))
        end
    }
  end

  def resource_topic do
    %{
      ResourceTopic:
        swagger_schema do
          title("ResourceTopic")
          description("A resource-topic in the application")

          properties do
            resource_id(:integer, "Resource id associated with the resource")
            topic_id(:integer, "Topic id associated with the resource")
          end

          example(%{
            resource_id: 1,
            topic_id: 1
          })
        end
    }
  end

  def resource_topics do
    %{
      ResourceTopics:
        swagger_schema do
          title("ResourceTopics")
          description("All resources-topics in the application")
          type(:array)
          items(Schema.ref(:ResourceTopic))
        end
    }
  end

  def resource_concept do
    %{
      ResourceConcept:
        swagger_schema do
          title("ResourceConcept")
          description("A resource-concept in the application")

          properties do
            resource_id(:integer, "Resource id associated with the resource")
            concept_id(:integer, "Concept id associated with the resource")
          end

          example(%{
            resource_id: 1,
            concept_id: 1
          })
        end
    }
  end

  def resource_concepts do
    %{
      ResourceConcepts:
        swagger_schema do
          title("ResourceConcepts")
          description("All resources-topics in the application")
          type(:array)
          items(Schema.ref(:ResourceConcept))
        end
    }
  end
end
