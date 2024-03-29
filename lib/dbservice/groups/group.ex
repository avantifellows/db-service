defmodule Dbservice.Groups.Group do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Dbservice.Users.User
  alias Dbservice.Sessions.Session

  schema "group" do
    field :type, :string
    field :child_id, :integer

    many_to_many :user, User, join_through: "group_user", on_replace: :delete
    many_to_many :session, Session, join_through: "group_session", on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :type,
      :child_id
    ])
    |> validate_required([:type, :child_id])
  end
end
