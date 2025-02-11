defmodule Dbservice.Purposes.Purpose do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "purpose" do
    field(:name, :string)
    field(:description, :string)

    timestamps()

  end

  @doc false
  def changeset(purpose, attrs) do
    purpose
    |> cast(attrs, [
      :name,
      :description
    ])
  end
end
