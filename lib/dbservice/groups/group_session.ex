defmodule Dbservice.Groups.GroupSession do
  @moduledoc false

  use Ecto.Schema
  alias Dbservice.Groups.Group
  alias Dbservice.Sessions.Session
  import Ecto.Changeset

  schema "group_session" do
    belongs_to :group, Group
    belongs_to :session, Session

    timestamps()
  end

  @doc false
  def changeset(group_user, attrs) do
    group_user
    |> cast(attrs, [
      :group_id,
      :session_id
    ])
    |> validate_required([:group_id, :session_id])
  end

  def changeset_update_sessions(group, sessions) do
    group
    |> change()
    |> put_assoc(:sessions, sessions)
  end
end
