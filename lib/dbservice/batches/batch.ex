defmodule Dbservice.Batches.Batch do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Sessions.Session
  alias Dbservice.Users.User

  schema "batch" do
    field :name, :string

    timestamps()

    many_to_many :sessions, Session, join_through: "batch_session", on_replace: :delete
    many_to_many :users, User, join_through: "batch_user", on_replace: :delete
  end

  @doc false
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  def changeset_update_users(batch, users) do
    batch
    |> change()
    |> put_assoc(:users, users)
  end
end
