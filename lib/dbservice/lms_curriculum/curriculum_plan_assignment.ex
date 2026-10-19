defmodule Dbservice.LmsCurriculum.CurriculumPlanAssignment do
  @moduledoc """
  Assigns a Curriculum Plan to a Centre. `grade_id` and `academic_year` are copied from the
  plan so the unique key allows one plan per Centre + Grade + academic year. Rows are
  deleted with their plan.

  `centre_id` is a plain field: `centres` is LMS-managed and has no Ecto schema here.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.LmsCurriculum.CurriculumPlan

  @timestamps_opts [type: :naive_datetime_usec]

  schema "lms_curriculum_plan_assignments" do
    field :centre_id, :id
    field :academic_year, :string
    field :inserted_by_email, :string
    field :updated_by_email, :string

    belongs_to :plan, CurriculumPlan
    belongs_to :grade, Dbservice.Grades.Grade

    timestamps()
  end

  @doc false
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [
      :plan_id,
      :centre_id,
      :grade_id,
      :academic_year,
      :inserted_by_email,
      :updated_by_email
    ])
    |> validate_required([:plan_id, :centre_id, :grade_id, :academic_year])
    |> foreign_key_constraint(:plan_id)
    |> foreign_key_constraint(:centre_id)
    |> foreign_key_constraint(:grade_id)
    |> unique_constraint([:centre_id, :grade_id, :academic_year],
      name: :lms_curriculum_plan_assignments_centre_grade_year_index
    )
  end
end
