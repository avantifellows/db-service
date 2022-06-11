defmodule Dbservice.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Batches.Batch

  schema "session" do
    field :end_time, :utc_datetime
    field :is_active, :boolean
    field :meta_data, :map
    field :name, :string
    field :platform, :string
    field :platform_link, :string
    field :portal_link, :string
    field :repeat_till_date, :utc_datetime
    field :repeat_type, :string
    field :start_time, :utc_datetime
    field :owner_id, :id
    field :created_by_id, :id

    timestamps()

    many_to_many :users, User, join_through: "user_session", on_replace: :delete
    many_to_many :batches, Batch, join_through: "batch_session", on_replace: :delete
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
      :repeat_type,
      :repeat_till_date,
      :meta_data
    ])
    |> validate_required([
      :name,
      :is_active,
      :platform,
      :platform_link,
      :portal_link,
      :start_time,
      :end_time,
      :repeat_type,
      :repeat_till_date,
      :meta_data
    ])
  end

  def changeset_update_batches(session, batches) do
    session
    |> change()
    |> put_assoc(:batches, batches)
  end
end
