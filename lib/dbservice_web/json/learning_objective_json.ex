defmodule DbserviceWeb.LearningObjectiveJSON do
  def index(%{learning_objective: learning_objective}) do
    %{data: for(lo <- learning_objective, do: data(lo))}
  end

  def show(%{learning_objective: learning_objective}) do
    %{data: data(learning_objective)}
  end

  def data(learning_objective) do
    %{
      id: learning_objective.id,
      title: learning_objective.title,
      concept_id: learning_objective.concept_id,
      tag_id: learning_objective.tag_id
    }
  end
end
