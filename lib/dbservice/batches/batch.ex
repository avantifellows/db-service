defmodule Dbservice.Batches.Batch do
  use Ecto.Schema
  import Ecto.Changeset

  schema "batch" do
    field :name, :string

    timestamps()

    many_to_many(:session, Session, join_through: "batch_session")
    many_to_many(:user, User, join_through: "batch_user")
  end

  @doc false
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
