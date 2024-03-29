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
  def changeset(group_session, attrs) do
    group_session
    |> cast(attrs, [
      :group_id,
      :session_id
    ])
    |> validate_required([:group_id, :session_id])
  end

  def changeset_update_sessions(group, sessions) do
    group
    |> change()
    |> put_assoc(:session, sessions)
  end
end
