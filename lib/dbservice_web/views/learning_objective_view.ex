defmodule DbserviceWeb.LearningObjectiveView do
  use DbserviceWeb, :view
  alias DbserviceWeb.LearningObjectiveView

  def render("index.json", %{learning_objective: learning_objective}) do
    render_many(learning_objective, LearningObjectiveView, "learning_objective.json")
  end

  def render("show.json", %{learning_objective: learning_objective}) do
    render_one(learning_objective, LearningObjectiveView, "learning_objective.json")
  end

  def render("learning_objective.json", %{learning_objective: learning_objective}) do
    %{
      id: learning_objective.id,
      title: learning_objective.title,
      concept_id: learning_objective.concept_id,
      tag_id: learning_objective.tag_id
    }
  end
end
