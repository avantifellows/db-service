defmodule Dbservice.Batches.Batch do
  use Ecto.Schema
  import Ecto.Changeset

  schema "batch" do
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
