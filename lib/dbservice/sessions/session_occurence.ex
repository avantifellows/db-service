defmodule Dbservice.Sessions.SessionOccurrence do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Users.User

  schema "session_occurrence" do
    field :end_time, :utc_datetime
    field :start_time, :utc_datetime
    field :session_id, :string

    timestamps()

    many_to_many :users, User, join_through: "user_session", on_replace: :delete
    belongs_to :session, Dbservice.Sessions.Session, foreign_key: :session_fk
  end

  @doc false
  def changeset(session_occurrence, attrs) do
    IO.inspect(attrs, label: "Attrs in session_occurrence changeset")

    session_occurrence
    |> cast(attrs, [:session_id, :start_time, :end_time, :session_fk])
    |> validate_required([:session_id])
    |> validate_start_end_date_time()
  end

  defp validate_start_end_date_time(changeset) do
    if get_field(changeset, :start_time, :end_time) != nil do
      validate_date_range(changeset, :start_time, :end_time)
    else
      changeset
    end
  end
end
