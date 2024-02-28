defmodule DbserviceWeb.SwaggerSchema.LearningObjective do
  @moduledoc false

  use PhoenixSwagger

  def learning_objective do
    %{
      LearningObjective:
        swagger_schema do
          title("LearningObjective")
          description("A learning objective in the application")

          properties do
            title(:string, "Title of the learning objective")
            concept_id(:integer, "Concept id associated with the learning objective")
            tag_id(:integer, "Tag id associated with the learning objective")
          end

          example(%{
            title: "Understanding fundamental concept of Electromagnetism",
            concept_id: 1,
            tag_id: 6
          })
        end
    }
  end

  def learning_objectives do
    %{
      LearningObjectives:
        swagger_schema do
          title("LearningObjectives")
          description("All learning objectives in the application")
          type(:array)
          items(Schema.ref(:LearningObjective))
        end
    }
  end
end
