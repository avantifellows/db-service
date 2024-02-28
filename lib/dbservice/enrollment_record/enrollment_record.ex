defmodule Dbservice.EnrollmentRecords.EnrollmentRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Users.Student

  schema "enrollment_record" do
    field(:academic_year, :string)
    field(:grade, :string)
    field(:is_current, :boolean, default: false)
    field(:board_medium, :string)
    field(:date_of_enrollment, :date)
    field(:grouping_id, :integer)
    field(:grouping_type, :string)

    belongs_to(:student, Student)

    timestamps()
  end

  @doc false
  def changeset(enrollment_record, attrs) do
    IO.inspect(attrs)

    enrollment_record
    |> cast(attrs, [
      :student_id,
      :grade,
      :academic_year,
      :is_current,
      :board_medium,
      :date_of_enrollment,
      :grouping_id,
      :grouping_type
    ])
    |> validate_required([:student_id, :grouping_id, :grouping_type, :date_of_enrollment])
    |> validate_date_of_enrollment
  end

  defp validate_date_of_enrollment(changeset) do
    if get_field(changeset, :date_of_enrollment) != nil do
      IO.inspect(:date_of_enrollment)
      invalidate_future_date(changeset, :date_of_enrollment)
    else
      changeset
    end
  end
end
