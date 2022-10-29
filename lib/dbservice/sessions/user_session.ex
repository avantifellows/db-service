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
    |> validate_required([:user_id, :start_time])
    |> validate_start_end_date_time
  end

  defp validate_start_end_date_time(changeset) do
    if get_field(changeset, :start_time, :end_time) do
      validate_start_end_datetime(changeset, :start_time, :end_time)
    else
      changeset
    end
  end
end
