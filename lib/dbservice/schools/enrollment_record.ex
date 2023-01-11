defmodule Dbservice.Schools.EnrollmentRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Users.Student
  alias Dbservice.Schools.School
  alias Dbservice.Groups.Group

  schema "enrollment_record" do
    field :academic_year, :string
    field :grade, :string
    field :is_current, :boolean, default: false
    field :board_medium, :string
    field :date_of_school_enrollment, :date
    field :date_of_group_enrollment, :date

    belongs_to :student, Student
    belongs_to :school, School
    belongs_to :group, Group

    timestamps()
  end

  @doc false
  def changeset(enrollment_record, attrs) do
    enrollment_record
    |> cast(attrs, [
      :student_id,
      :school_id,
      :grade,
      :academic_year,
      :is_current,
      :board_medium,
      :date_of_school_enrollment,
      :date_of_group_enrollment,
      :group_id
    ])
    |> validate_required([:student_id, :school_id])
    |> validate_date_of_school_enrollment
  end

  defp validate_date_of_school_enrollment(changeset) do
    if get_field(changeset, :date_of_school_enrollment) != nil do
      invalidate_future_date(changeset, :date_of_school_enrollment)
    else
      changeset
    end
  end
end
