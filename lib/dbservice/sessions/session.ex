defmodule Dbservice.Sessions.Session do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Groups.Group
  alias Dbservice.Sessions.SessionSchedule

  schema "session" do
    field(:end_time, :utc_datetime)
    field(:meta_data, :map)
    field(:name, :string)
    field(:platform, :string)
    field(:platform_link, :string)
    field(:portal_link, :string)
    field(:start_time, :utc_datetime)
    field(:owner_id, :id)
    field(:created_by_id, :id)
    field(:session_id, :string)
    field(:is_active, :boolean)
    field(:purpose, :map)
    field(:repeat_schedule, :map)
    field(:platform_id, :string)
    field(:type, :string)
    field(:auth_type, :string)
    field(:signup_form, :boolean)
    field(:signup_form_id, :integer)
    field(:id_generation, :boolean)
    field(:redirection, :boolean)
    field(:popup_form, :boolean)
    field(:popup_form_id, :integer)

    timestamps()

    many_to_many(:users, User, join_through: "user_session", on_replace: :delete)
    many_to_many(:group, Group, join_through: "group_session", on_replace: :delete)
    has_many(:session_schedule, SessionSchedule)
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
      :session_id,
      :purpose,
      :repeat_schedule,
      :platform_id,
      :type,
      :auth_type,
      :signup_form,
      :id_generation,
      :redirection,
      :popup_form,
      :popup_form_id,
      :signup_form_id
    ])
    |> validate_required([
      :name
    ])
  end

  def changeset_update_groups(session, groups) do
    session
    |> change()
    |> put_assoc(:group, groups)
  end
end
