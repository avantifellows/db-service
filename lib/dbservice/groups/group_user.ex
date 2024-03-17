defmodule Dbservice.Groups.GroupUser do
  @moduledoc false

  use Ecto.Schema
  alias Dbservice.Users.User
  alias Dbservice.Groups.Group
  import Ecto.Changeset

  schema "group_user" do

    belongs_to :group, Group
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(group_user, attrs) do
    group_user
    |> cast(attrs, [
      :group_id,
      :user_id
    ])
    |> validate_required([:group_id, :user_id])
  end

  def changeset_update_users(group, users) do
    group
    |> change()
    |> put_assoc(:user, users)
  end
end
