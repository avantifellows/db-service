defmodule Dbservice.Groups.GroupUser do
  @moduledoc false

  use Ecto.Schema
  alias Dbservice.Users.User
  alias Dbservice.Groups.Group
  import Ecto.Changeset
  import Dbservice.Utils.Util

  schema "group_user" do
    field :program_date_of_joining, :utc_datetime
    field :program_student_language, :string
    belongs_to :group, Group
    belongs_to :user, User
    belongs_to :program_manager, User

    timestamps()
  end

  @doc false
  def changeset(group_user, attrs) do
    group_user
    |> cast(attrs, [
      :group_id,
      :user_id,
      :program_manager_id,
      :program_date_of_joining,
      :program_student_language
    ])
    |> validate_required([:group_id, :user_id])
    |> validate_program_date_of_joining
  end

  def changeset_update_users(group, users) do
    group
    |> change()
    |> put_assoc(:user, users)
  end

  defp validate_program_date_of_joining(changeset) do
    if get_field(changeset, :program_date_of_joining) != nil do
      invalidate_future_date(changeset, :program_date_of_joining)
    else
      changeset
    end
  end
end
