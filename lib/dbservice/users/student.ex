defmodule Dbservice.Users.Student do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Schools.EnrollmentRecord

  schema "student" do
    field(:category, :string)
    field(:father_name, :string)
    field(:father_phone, :string)
    field(:mother_name, :string)
    field(:mother_phone, :string)
    field(:stream, :string)
    field(:student_id, :string)
    field(:physically_handicapped, :boolean)
    field(:family_income, :string)
    field(:father_profession, :string)
    field(:father_education_level, :string)
    field(:mother_profession, :string)
    field(:mother_education_level, :string)
    field(:has_internet_access, :string)
    field(:time_of_device_availability, :string)
    field(:primary_smartphone_owner, :string)
    field(:primary_smartphone_owner_profession, :string)
    field(:is_dropper, :boolean)
    field(:contact_hours_per_week, :integer)
    belongs_to(:user, User)
    has_many(:enrollment_record, EnrollmentRecord)

    timestamps()
  end

  def changeset(student, attrs) do
    student
    |> cast(attrs, [
      :user_id,
      :student_id,
      :father_name,
      :father_phone,
      :mother_name,
      :mother_phone,
      :category,
      :stream,
      :physically_handicapped,
      :family_income,
      :father_profession,
      :father_education_level,
      :mother_profession,
      :mother_education_level,
      :time_of_device_availability,
      :has_internet_access,
      :primary_smartphone_owner,
      :primary_smartphone_owner_profession,
      :is_dropper,
      :contact_hours_per_week
    ])
    |> validate_required([:user_id])
  end
end
