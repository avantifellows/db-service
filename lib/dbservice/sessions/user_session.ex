defmodule Dbservice.Sessions.UserSession do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Sessions.SessionOccurence

  schema "user_session" do
    field :end_time, :utc_datetime
    field :start_time, :utc_datetime
    field :data, :map
    field :is_user_valid, :boolean
    field :user_id, :string

    timestamps()

    belongs_to :session_occurrence, SessionOccurence
  end

  @doc false
  def changeset(user_session, attrs) do
    user_session
    |> cast(attrs, [
      :start_time,
      :end_time,
      :data,
      :session_occurrence_id,
      :is_user_valid,
      :user_id
    ])
    |> validate_required([:start_time])
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
