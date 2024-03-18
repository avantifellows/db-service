defmodule Dbservice.Sessions.UserSession do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Sessions.SessionOccurence
  alias Dbservice.Users.User

  schema "user_session" do
    field :timestamp, :utc_datetime
    field :data, :map
    field :type, :string

    timestamps()

    belongs_to :session_occurrence, SessionOccurence
    belongs_to :user, User
  end

  @doc false
  def changeset(user_session, attrs) do
    user_session
    |> cast(attrs, [
      :timestamp,
      :type,
      :data,
      :session_occurrence_id,
      :user_id
    ])
    |> validate_required([:user_id, :session_occurrence_id, :timestamp, :type])
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
