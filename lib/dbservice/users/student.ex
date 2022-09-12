defmodule Dbservice.Users.Student do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Groups.Group
  alias Dbservice.Schools.EnrollmentRecord

  schema "student" do
    field :category, :string
    field :father_name, :string
    field :father_phone, :string
    field :mother_name, :string
    field :mother_phone, :string
    field :stream, :string
    field :uuid, :string
    field :physically_handicapped, :boolean
    field :cohort, :string
    field :family_income, :string
    field :father_profession, :string
    field :father_education_level, :string
    field :mother_profession, :string
    field :mother_education_level, :string
    field :time_of_device_availability, :date
    field :has_internet_access, :boolean
    field :primary_smartphone_owner, :string
    field :primary_smartphone_owner_profession, :string
    belongs_to :user, User
    belongs_to :group, Group
    has_one :enrollment_record, EnrollmentRecord

    timestamps()
  end

  @doc false
  def changeset(student, attrs) do
    student
    |> cast(attrs, [
      :user_id,
      :group_id,
      :uuid,
      :father_name,
      :father_phone,
      :mother_name,
      :mother_phone,
      :category,
      :stream,
      :physically_handicapped,
      :cohort,
      :family_income,
      :father_profession,
      :father_education_level,
      :mother_profession,
      :mother_education_level,
      :time_of_device_availability,
      :has_internet_access,
      :primary_smartphone_owner,
      :primary_smartphone_owner_profession
    ])
    |> validate_required([:user_id, :group_id, :uuid])
  end
end
