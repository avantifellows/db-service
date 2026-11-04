defmodule Dbservice.Centres.Centre do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Groups.Group
  alias Dbservice.Programs.Program
  alias Dbservice.Schools.School
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  schema "centres" do
    field :name, :string
    field :type_code, :string
    field :category_code, :string
    field :sub_category_code, :string
    field :stream_codes, {:array, :string}, default: []
    field :is_physical, :boolean, default: false
    field :is_active, :boolean, default: true

    belongs_to :school, School
    belongs_to :program, Program

    has_many :group, Group, foreign_key: :child_id, where: [type: "centre"]

    has_many :enrollment_record, EnrollmentRecord,
      foreign_key: :group_id,
      where: [group_type: "centre"]

    timestamps()
  end

  @doc false
  def changeset(centre, attrs) do
    centre
    |> cast(attrs, [
      :name,
      :school_id,
      :program_id,
      :type_code,
      :category_code,
      :sub_category_code,
      :stream_codes,
      :is_physical,
      :is_active
    ])
    |> validate_required([:name])
    |> foreign_key_constraint(:school_id)
    |> foreign_key_constraint(:program_id)
    # Surfaces the partial unique index from 20260706120000 as a changeset error
    # rather than an unhandled Ecto.ConstraintError: at most one ACTIVE centre
    # per (school, program), the pair `centre_students` attributes students by.
    |> unique_constraint([:school_id, :program_id],
      name: :centres_active_school_program_unique,
      message: "an active centre already exists for this school and program"
    )
  end
end
