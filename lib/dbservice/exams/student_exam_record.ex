defmodule Dbservice.Exams.StudentExamRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Exams.Exam
  alias Dbservice.Users.Student

  # JEE Main has run at most four sittings in a year (2021), and no exam we
  # hold records for runs more often. A number outside that range is a typo,
  # not a sitting the student could have applied for.
  @max_exam_session 4

  schema "student_exam_record" do
    field :application_number, :string
    field :application_password, :string
    field :date, :date
    field :score, :float
    field :percentile, :float
    field :all_india_rank, :integer
    field :category_rank, :integer
    field :sessions_applied, {:array, :integer}

    belongs_to(:exam, Exam)
    belongs_to(:student, Student)

    timestamps()
  end

  @doc false
  def changeset(student_exam_record, attrs) do
    student_exam_record
    |> cast(attrs, [
      :student_id,
      :exam_id,
      :application_number,
      :application_password,
      :date,
      :score,
      :percentile,
      :all_india_rank,
      :category_rank,
      :sessions_applied
    ])
    |> validate_required([:student_id, :application_number, :exam_id])
    |> normalize_sessions_applied()
    |> validate_sessions_applied()
  end

  # The sittings a student applied for are a set: order and repeats carry no
  # meaning, so [2, 1, 2] and [1, 2] are stored as the same value. An empty
  # list says no more than no answer at all, so it is stored as NULL.
  defp normalize_sessions_applied(changeset) do
    update_change(changeset, :sessions_applied, fn
      nil -> nil
      [] -> nil
      sessions -> sessions |> Enum.uniq() |> Enum.sort()
    end)
  end

  defp validate_sessions_applied(changeset) do
    validate_change(changeset, :sessions_applied, fn :sessions_applied, sessions ->
      if Enum.all?(sessions, &(&1 >= 1 and &1 <= @max_exam_session)) do
        []
      else
        [sessions_applied: "must be session numbers between 1 and #{@max_exam_session}"]
      end
    end)
  end
end
