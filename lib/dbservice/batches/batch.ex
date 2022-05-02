defmodule Dbservice.Batches.Batch do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Sessions.Session
  alias Dbservice.Users.User

  schema "batch" do
    field :name, :string

    timestamps()

    many_to_many :session, Session, join_through: "batch_session", on_replace: :delete
    many_to_many :user, User, join_through: "batch_user", on_replace: :delete
  end

  @doc false
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
