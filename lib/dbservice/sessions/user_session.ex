defmodule Dbservice.Sessions.UserSession do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Users.User
  alias Dbservice.Sessions.SessionOccurence

  schema "user_session" do
    field :end_time, :utc_datetime
    field :start_time, :utc_datetime
    field :data, :map

    timestamps()

    belongs_to :user, User
    belongs_to :session_occurence, SessionOccurence
  end

  @doc false
  def changeset(user_session, attrs) do
    user_session
    |> cast(attrs, [:start_time, :end_time, :data, :user_id, :session_occurence_id])
    |> validate_required([:user_id, :session_occurence_id, :start_time])
    |> validate_date_time
  end

  defp validate_date_time(changeset) do
    validate_date_time(changeset, :start_time, :end_time)
  end
end
