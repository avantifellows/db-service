defmodule Dbservice.Tags.Tag do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset


  schema "tag" do
    field(:name, :string)
    field(:description, :string)

    timestamps()

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
