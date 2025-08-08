defmodule DbserviceWeb.LearningObjectiveJSON do
  def index(%{learning_objective: learning_objective}) do
    for(lo <- learning_objective, do: render(lo))
  end

  def show(%{learning_objective: learning_objective}) do
    render(learning_objective)
  end

  defp render(learning_objective) do
    %{
      id: learning_objective.id,
      title: learning_objective.title,
      concept_id: learning_objective.concept_id
    }
  end
end
