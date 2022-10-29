defmodule Dbservice.Users.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Sessions.SessionOccurence
  alias Dbservice.Sessions.UserSession
  alias Dbservice.Users.Teacher
  alias Dbservice.Users.Student
  alias Dbservice.Groups.Group

  schema "user" do
    field :address, :string
    field :city, :string
    field :district, :string
    field :email, :string
    field :full_name, :string
    field :gender, :string
    field :phone, :string
    field :pincode, :string
    field :role, :string
    field :state, :string
    field :whatsapp_phone, :string
    field :date_of_birth, :date

    timestamps()

    many_to_many :sessions, SessionOccurence, join_through: "user_session", on_replace: :delete
    has_many :user_session, UserSession
    has_one :teacher, Teacher
    has_one :student, Student
    many_to_many :group, Group, join_through: "group_user", on_replace: :delete
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :full_name,
      :email,
      :phone,
      :gender,
      :address,
      :city,
      :district,
      :state,
      :pincode,
      :role,
      :whatsapp_phone,
      :date_of_birth
    ])
    |> validate_required([:full_name])
    |> validate_format(:phone, ~r{\A\d*\z})
    |> validate_date_of_birth
  end

  def changeset_update_groups(user, groups) do
    user
    |> change()
    |> put_assoc(:group, groups)
  end

  defp validate_date_of_birth(changeset) do
    if get_field(changeset, :date_of_birth) != nil do
      invalidate_future_date(changeset, :date_of_birth)
    else
      changeset
    end
  end
end
