defmodule Dbservice.Users.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

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
    field :first_name, :string
    field :gender, :string
    field :last_name, :string
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
      :first_name,
      :last_name,
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
    |> validate_required([:first_name, :last_name, :email, :phone])
  end

  def changeset_update_groups(user, group) do
    user
    |> change()
    |> put_assoc(:group, group)
  end
end
