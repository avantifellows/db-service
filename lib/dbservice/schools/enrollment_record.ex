defmodule Dbservice.Schools.EnrollmentRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.Student
  alias Dbservice.Schools.School

  schema "enrollment_record" do
    field :academic_year, :string
    field :grade, :string
    field :is_current, :boolean, default: false
    field :board_medium, :string
    field :date_of_enrollment, :date

    belongs_to :student, Student
    belongs_to :school, School

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
      :date_of_enrollment
    ])
    |> validate_required([:student_id, :school_id])
    |> validate_date_of_enrollment
  end

  defp validate_date_of_enrollment(changeset) do
    todays_date = Date.utc_today()
    date_of_enrollment = get_field(changeset, :date_of_enrollment)

    if Date.compare(date_of_enrollment, todays_date) == :gt do
      add_error(changeset, :date_of_enrollment, "cannot be later than today's date")
    else
      changeset
    end
  end
end
