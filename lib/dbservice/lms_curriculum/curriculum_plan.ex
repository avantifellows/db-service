defmodule Dbservice.LmsCurriculum.CurriculumPlan do
  @moduledoc """
  An LMS Curriculum Plan: a Chapter Due Date (and optional Chapter Test Date) for each
  in-syllabus Chapter of one Grade's served Exam Tracks in one academic year.

  The LMS app reads and writes this table directly with SQL; this schema documents the
  shape and maps the database constraints for any Elixir-side writes. "Closed" is derived
  from `closure_date` and never stored, so `status` is `draft` or `active`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.LmsCurriculum.CurriculumPlanAssignment
  alias Dbservice.LmsCurriculum.CurriculumPlanChapter

  @statuses ~w(draft active)
  @exam_tracks ~w(jee_main jee_advanced neet)

  @timestamps_opts [type: :naive_datetime_usec]

  schema "lms_curriculum_plans" do
    field :title, :string
    field :academic_year, :string
    field :exam_tracks, {:array, :string}
    field :status, :string, default: "draft"
    field :closure_date, :date
    field :activated_at, :naive_datetime_usec
    field :inserted_by_email, :string
    field :updated_by_email, :string

    belongs_to :grade, Dbservice.Grades.Grade
    has_many :chapters, CurriculumPlanChapter, foreign_key: :plan_id
    has_many :assignments, CurriculumPlanAssignment, foreign_key: :plan_id

    timestamps()
  end

  def statuses, do: @statuses
  def exam_tracks, do: @exam_tracks

  @doc false
  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [
      :title,
      :academic_year,
      :grade_id,
      :exam_tracks,
      :status,
      :closure_date,
      :activated_at,
      :inserted_by_email,
      :updated_by_email
    ])
    |> validate_required([
      :title,
      :academic_year,
      :grade_id,
      :exam_tracks,
      :status,
      :closure_date
    ])
    |> validate_academic_year()
    |> validate_length(:exam_tracks, min: 1)
    |> validate_subset(:exam_tracks, @exam_tracks)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:grade_id)
    |> check_constraint(:title, name: :lms_curriculum_plans_title_check)
    |> check_constraint(:academic_year, name: :lms_curriculum_plans_academic_year_check)
    |> check_constraint(:exam_tracks, name: :lms_curriculum_plans_exam_tracks_check)
    |> check_constraint(:status, name: :lms_curriculum_plans_status_check)
  end

  # "2026-2027": four-digit years, the second one after the first.
  defp validate_academic_year(changeset) do
    validate_change(changeset, :academic_year, fn :academic_year, value ->
      case Regex.run(~r/\A(\d{4})-(\d{4})\z/, value) do
        [_, first, second] ->
          if String.to_integer(second) == String.to_integer(first) + 1,
            do: [],
            else: [academic_year: "must be two consecutive years, e.g. 2026-2027"]

        _ ->
          [academic_year: "must look like 2026-2027"]
      end
    end)
  end
end
