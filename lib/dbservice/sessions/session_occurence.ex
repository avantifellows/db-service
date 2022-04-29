defmodule Dbservice.Sessions.SessionOccurence do
  use Ecto.Schema
  import Ecto.Changeset

  schema "session_occurence" do
    field :end_time, :utc_datetime
    field :start_time, :utc_datetime
    field :session_id, :id

    timestamps()
  end

  @doc false
  def changeset(session_occurence, attrs) do
    session_occurence
    |> cast(attrs, [:start_time, :end_time])
    |> validate_required([:start_time, :end_time])
  end
end
