defmodule Dbservice.Tags.Tag do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Topics.Topic
  alias Dbservice.Sources.Source
  alias Dbservice.Resources.Resource

  schema "tag" do
    field(:name, :string)
    field(:description, :string)

    timestamps()

    has_one(:topic, Topic)
    has_one(:source, Source)
    has_one(:resource, Resource)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [
      :name,
      :description
    ])
  end
end
