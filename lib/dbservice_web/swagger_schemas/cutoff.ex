defmodule DbserviceWeb.SwaggerSchema.Cutoff do
  @moduledoc false

  use PhoenixSwagger

  def cutoff do
    %{
      Cutoff:
        swagger_schema do
          title("Cutoff")
          description("A cutoff record in the application")

          properties do
            cutoff_year(:integer, "The year of the cutoff")
            exam_occurrence_id(:integer, "The exam occurrence ID")
            college_id(:integer, "The college ID")
            degree(:string, "The degree type")
            branch_id(:integer, "The branch ID")
            category(:string, "The category")
            state_quota(:string, "State quota type")
            opening_rank(:integer, "Opening rank")
            closing_rank(:integer, "Closing rank")
          end

          example(%{
            cutoff_year: 2024,
            exam_occurrence_id: 1,
            college_id: 1,
            degree: "B.Tech",
            branch_id: 1,
            category: "General",
            state_quota: "All India",
            opening_rank: 1000,
            closing_rank: 5000
          })
        end
    }
  end

  def cutoffs do
    %{
      Cutoffs:
        swagger_schema do
          title("Cutoffs")
          description("All the cutoffs")
          type(:array)
          items(Schema.ref(:Cutoff))
        end
    }
  end
end
