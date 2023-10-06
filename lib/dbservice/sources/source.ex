defmodule Dbservice.Sources.Source do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Tags.Tag
  alias Dbservice.Resources.Resource

  schema "source" do
    field(:name, :string)
    field(:link, :string)

    timestamps()

    has_many(:resource, Resource)
    belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [
      :name,
      :link,
      :tag_id
    ])
  end
end
