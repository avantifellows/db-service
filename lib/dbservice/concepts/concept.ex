defmodule Dbservice.Concepts.Concept do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Topics.Topic
  alias Dbservice.LearningObjectives.LearningObjective

  schema "concept" do
    field(:name, {:array, :map})

    timestamps()

    has_many(:learning_objective, LearningObjective)
    belongs_to(:topic, Topic)
  end

  @doc false
  def changeset(concept, attrs) do
    concept
    |> cast(attrs, [
      :name,
      :topic_id
    ])
  end
end
