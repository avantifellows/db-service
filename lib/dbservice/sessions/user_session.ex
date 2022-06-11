defmodule Dbservice.Sessions.UserSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_session" do
    field :end_time, :utc_datetime
    field :start_time, :utc_datetime
    field :data, :map

    timestamps()

    belongs_to :user, Users.User
    belongs_to :session_occurence, Sessions.SessionOccurence
  end

  @doc false
  def changeset(user_session, attrs) do
    user_session
    |> cast(attrs, [:start_time, :end_time, :data, :user_id, :session_occurence_id])
    |> validate_required([:user_id, :session_occurence_id, :start_time, :end_time])
  end
end
