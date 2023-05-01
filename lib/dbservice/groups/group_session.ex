defmodule Dbservice.Groups.GroupSession do
  @moduledoc false

  use Ecto.Schema
  alias Dbservice.Groups.GroupType
  alias Dbservice.Sessions.Session
  import Ecto.Changeset

  schema "group_session" do
    belongs_to :group_type, GroupType
    belongs_to :session, Session

    timestamps()
  end

  @doc false
  def changeset(group_session, attrs) do
    group_session
    |> cast(attrs, [
      :group_type_id,
      :session_id
    ])
    |> validate_required([:group_type_id, :session_id])
  end

  def changeset_update_sessions(group, sessions) do
    group
    |> change()
    |> put_assoc(:session, sessions)
  end
end
