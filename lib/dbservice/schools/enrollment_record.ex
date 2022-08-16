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
    field :course_language, :string
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
      :course_language,
      :date_of_enrollment
    ])
    |> validate_required([:student_id, :school_id])
  end
end
