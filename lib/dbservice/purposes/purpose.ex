defmodule Dbservice.Purposes.Purpose do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Tags.Tag
  alias Dbservice.Resources.Resource

  schema "purpose" do
    field(:name, :string)
    field(:description, :string)

    timestamps()

    has_many(:resource, Resource)
    belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(purpose, attrs) do
    purpose
    |> cast(attrs, [
      :name,
      :description,
      :tag_id
    ])
  end
end
