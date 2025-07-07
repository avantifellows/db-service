defmodule Dbservice.Resources.ResourceConcept do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Resources.Resource
  alias Dbservice.Concepts.Concept

  schema "resource_concept" do
    belongs_to :resource, Resource
    belongs_to :concept, Concept

    timestamps()
  end

  @doc false
  def changeset(resource_topic, attrs) do
    resource_topic
    |> cast(attrs, [
      :resource_id,
      :concept_id
    ])
    |> validate_required([
      :resource_id,
      :concept_id
    ])
  end
end
