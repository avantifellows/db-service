defmodule Dbservice.LearningObjectives.LearningObjective do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Concepts.Concept
  alias Dbservice.Tags.Tag
  alias Dbservice.Resources.Resource

  schema "learning_objective" do
    field(:title, :string)

    timestamps()

    has_many(:resource, Resource)
    belongs_to(:concept, Concept)
    belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(learning_objective, attrs) do
    learning_objective
    |> cast(attrs, [
      :title,
      :concept_id,
      :tag_id
    ])
  end
end
