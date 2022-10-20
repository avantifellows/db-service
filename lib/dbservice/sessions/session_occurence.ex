defmodule Dbservice.Sessions.SessionOccurence do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User

  schema "session_occurence" do
    field :end_time, :utc_datetime
    field :start_time, :utc_datetime
    field :session_id, :id

    timestamps()

    many_to_many :users, User, join_through: "user_session", on_replace: :delete
  end

  @doc false
  def changeset(session_occurence, attrs) do
    session_occurence
    |> cast(attrs, [:session_id, :start_time, :end_time])
    |> validate_required([:session_id, :start_time, :end_time])
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
