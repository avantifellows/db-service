defmodule Dbservice.LmsCurriculum.CurriculumPlanChapter do
  @moduledoc """
  A Curriculum Plan's dates for one Chapter. Both dates are optional (an undated Chapter is
  "Not in plan"), but a Chapter Test Date requires a Chapter Due Date. Rows are deleted
  with their plan.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.LmsCurriculum.CurriculumPlan

  @timestamps_opts [type: :naive_datetime_usec]

  schema "lms_curriculum_plan_chapters" do
    field :due_date, :date
    field :test_date, :date
    field :inserted_by_email, :string
    field :updated_by_email, :string

    belongs_to :plan, CurriculumPlan
    belongs_to :chapter, Dbservice.Chapters.Chapter

    timestamps()
  end

  @doc false
  def changeset(plan_chapter, attrs) do
    plan_chapter
    |> cast(attrs, [
      :plan_id,
      :chapter_id,
      :due_date,
      :test_date,
      :inserted_by_email,
      :updated_by_email
    ])
    |> validate_required([:plan_id, :chapter_id])
    |> validate_test_date_requires_due_date()
    |> foreign_key_constraint(:plan_id)
    |> foreign_key_constraint(:chapter_id)
    |> unique_constraint([:plan_id, :chapter_id],
      name: :lms_curriculum_plan_chapters_plan_id_chapter_id_index
    )
    |> check_constraint(:test_date,
      name: :lms_curriculum_plan_chapters_test_date_requires_due_date
    )
  end

  defp validate_test_date_requires_due_date(changeset) do
    if get_field(changeset, :test_date) && is_nil(get_field(changeset, :due_date)) do
      add_error(changeset, :test_date, "requires a due date")
    else
      changeset
    end
  end
end
