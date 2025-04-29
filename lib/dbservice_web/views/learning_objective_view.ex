defmodule DbserviceWeb.LearningObjectiveView do
  use DbserviceWeb, :view

  def render("index.json", %{learning_objective: learning_objectives}) do
    Enum.map(learning_objectives, &learning_objective_json/1)
  end

  def render("show.json", %{learning_objective: learning_objective}) do
    learning_objective_json(learning_objective)
  end

  def learning_objective_json(%{__meta__: _} = learning_objective) do
    %{
      id: learning_objective.id,
      name: learning_objective.name,
      description: learning_objective.description,
      type: learning_objective.type
    }
  end
end
