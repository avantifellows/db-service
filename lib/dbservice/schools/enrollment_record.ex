defmodule Dbservice.Schools.EnrollmentRecord do
  use Ecto.Schema
  import Ecto.Changeset

  schema "enrollment_record" do
    field :academic_year, :string
    field :grade, :string
    field :is_current, :boolean, default: false
    belongs_to :student, Users.Student
    belongs_to :school, Schools.School

    timestamps()
  end

  @doc false
  def changeset(enrollment_record, attrs) do
    enrollment_record
    |> cast(attrs, [:student_id, :school_id, :grade, :academic_year, :is_current])
    |> validate_required([:student_id, :school_id])
  end
end
