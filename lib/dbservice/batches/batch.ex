defmodule Dbservice.Batches.Batch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Sessions.Session
  alias Dbservice.Users.User
  alias Dbservice.Programs.Program

  schema "batch" do
    field :name, :string
    field :contact_hours_per_week, :integer

    timestamps()

    many_to_many :sessions, Session, join_through: "batch_session", on_replace: :delete
    many_to_many :users, User, join_through: "batch_user", on_replace: :delete
    belongs_to :program, Program
  end

  @doc false
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [:name, :program_id, :contact_hours_per_week])
    |> validate_required([:name])
  end

  def changeset_update_users(batch, users) do
    batch
    |> change()
    |> put_assoc(:users, users)
  end

  def changeset_update_sessions(batch, sessions) do
    batch
    |> change()
    |> put_assoc(:sessions, sessions)
  end
end
