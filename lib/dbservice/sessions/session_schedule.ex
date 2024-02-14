defmodule Dbservice.Sessions.SessionSchedule do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Sessions.Session
  alias Dbservice.Batches.Batch

  schema "session_schedule" do
    field(:day_of_week, :string)
    field(:start_time, :time)
    field(:end_time, :time)

    timestamps()

    belongs_to(:session, Session)
    belongs_to(:batch, Batch)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_id,
      :day_of_week,
      :start_time,
      :end_time,
      :batch_id
    ])
  end
end
