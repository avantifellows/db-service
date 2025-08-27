defmodule Dbservice.Users.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Sessions.SessionOccurrence
  alias Dbservice.Users.Teacher
  alias Dbservice.Users.Student
  alias Dbservice.Users.Candidate
  alias Dbservice.Profiles.UserProfile
  alias Dbservice.Groups.Group
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Schools.School

  schema "user" do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:phone, :string)
    field(:date_of_birth, :date)
    field(:gender, :string)
    field(:whatsapp_phone, :string)
    field(:address, :string)
    field(:city, :string)
    field(:district, :string)
    field(:state, :string)
    field(:region, :string)
    field(:pincode, :string)
    field(:role, :string)
    field(:country, :string)

    timestamps()

    many_to_many(:sessions, SessionOccurrence, join_through: "user_session", on_replace: :delete)
    has_one(:teacher, Teacher)
    has_one(:student, Student)
    has_one(:candidate, Candidate)
    has_one(:user_profile, UserProfile)
    has_many(:enrollment_record, EnrollmentRecord)
    many_to_many(:group, Group, join_through: "group_user", on_replace: :delete)
    has_one(:school, School)
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
      :region,
      :pincode,
      :role,
      :whatsapp_phone,
      :date_of_birth,
      :country
    ])
    |> validate_format(:phone, ~r{\A\d*\z})
    |> validate_date_of_birth
    |> validate_gender(:gender)
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
