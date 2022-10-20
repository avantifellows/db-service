defmodule Dbservice.Sessions.UserSession do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

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
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if DateTime.compare(start_time, end_time) == :gt do
      add_error(changeset, :start_time, "cannot be later than end time")
    else
      changeset
    end
  end
end
