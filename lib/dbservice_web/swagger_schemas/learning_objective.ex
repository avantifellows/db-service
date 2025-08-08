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
            title(
              Schema.array(:object),
              "Multilingual titles for the learning objective",
              example: [
                %{lang: "en", value: "Understanding fundamental concept of Electromagnetism"},
                %{lang: "hi", value: "विद्युत चुंबकत्व की मौलिक अवधारणा को समझना"}
              ]
            )

            concept_id(:integer, "Concept id associated with the learning objective")
          end

          example(%{
            title: [
              %{lang: "en", value: "Understanding fundamental concept of Electromagnetism"},
              %{lang: "hi", value: "विद्युत चुंबकत्व की मौलिक अवधारणा को समझना"}
            ],
            concept_id: 1
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
