defmodule Dbservice.Sessions.UserSession do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Sessions.Session
  alias Dbservice.Users.User

  schema "user_session" do
    field :timestamp, :utc_datetime
    field :data, :map
    field :user_activity_type, :string
    field :user_activity_sub_type, :string

    timestamps()

    belongs_to :session, Session
    belongs_to :user, User
  end

  @doc false
  def changeset(user_session, attrs) do
    user_session
    |> cast(attrs, [
      :timestamp,
      :user_activity_type,
      :data,
      :session_id,
      :user_id
    ])
    |> validate_required([:user_id, :session_id, :timestamp, :user_activity_type])
    |> validate_start_end_date_time
  end

  defp validate_start_end_date_time(changeset) do
    if get_field(changeset, :timestamp) do
      invalidate_future_date(changeset, :timestamp)
    else
      changeset
    end
  end
end
