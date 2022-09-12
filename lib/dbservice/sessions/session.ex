defmodule Dbservice.Sessions.Session do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Groups.Group

  schema "session" do
    field :end_time, :utc_datetime
    field :meta_data, :map
    field :name, :string
    field :platform, :string
    field :platform_link, :string
    field :portal_link, :string
    field :start_time, :utc_datetime
    field :owner_id, :id
    field :created_by_id, :id
    field :uuid, :binary_id, read_after_writes: true
    field :is_active, :boolean
    field :purpose, :map
    field :repeat_schedule, :map

    timestamps()

    many_to_many :users, User, join_through: "user_session", on_replace: :delete
    many_to_many :group, Group, join_through: "group_session", on_replace: :delete
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :name,
      :is_active,
      :platform,
      :platform_link,
      :portal_link,
      :start_time,
      :end_time,
      :meta_data,
      :owner_id,
      :created_by_id,
      :uuid,
      :purpose,
      :repeat_schedule
    ])
    |> validate_required([
      :name,
      :is_active,
      :platform,
      :platform_link,
      :portal_link,
      :start_time,
      :end_time,
      :meta_data
    ])
  end

  def changeset_update_batches(session, batches) do
    session
    |> change()
    |> put_assoc(:batches, batches)
  end
end
