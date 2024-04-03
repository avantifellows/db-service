defmodule Dbservice.Concepts.Concept do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Topics.Topic
  alias Dbservice.Tags.Tag
  alias Dbservice.LearningObjectives.LearningObjective
  alias Dbservice.Resources.Resource

  schema "concept" do
    field(:name, :string)

    timestamps()

    has_many(:learning_objective, LearningObjective)
    has_many(:resource, Resource)
    belongs_to(:topic, Topic)
    belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(concept, attrs) do
    concept
    |> cast(attrs, [
      :name,
      :topic_id,
      :tag_id
    ])
  end
end
