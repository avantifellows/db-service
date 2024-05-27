defmodule Dbservice.Sessions.UserSession do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Sessions.Session
  alias Dbservice.Sessions.SessionOccurrence
  alias Dbservice.Users.User

  schema "user_session" do
    field :timestamp, :utc_datetime
    field :data, :map
    field :user_activity_type, :string

    timestamps()

    belongs_to :session, Session
    belongs_to :session_occurrence, SessionOccurrence
    belongs_to :user, User
  end

  @doc false
  def changeset(user_session, attrs) do
    IO.inspect(attrs)

    user_session
    |> cast(attrs, [
      :timestamp,
      :user_activity_type,
      :data,
      :session_id,
      :session_occurrence_id,
      :user_id
    ])
    |> validate_required([
      :user_id,
      :session_id,
      :timestamp,
      :session_occurrence_id,
      :user_activity_type
    ])
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
