defmodule Dbservice.Schools.EnrollmentRecord do
  use Ecto.Schema
  import Ecto.Changeset

  schema "enrollment_record" do
    field :academic_year, :string
    field :grade, :string
    field :is_current, :boolean, default: false
    field :student_id, :id
    field :school_id, :id

    timestamps()
  end

  @doc false
  def changeset(enrollment_record, attrs) do
    enrollment_record
    |> cast(attrs, [:grade, :academic_year, :is_current])
    |> validate_required([:grade, :academic_year, :is_current])
  end
end
