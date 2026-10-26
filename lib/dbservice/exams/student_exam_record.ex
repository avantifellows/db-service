defmodule Dbservice.Exams.StudentExamRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Exams.Exam
  alias Dbservice.Users.Student

  # JEE Main has run at most four sittings in a year (2021), and no exam we
  # hold records for runs more often. A number outside that range is a typo,
  # not a sitting the student could have applied for.
  @max_exam_session 4

  # The first exam year we would ever hold a record for; anything below this is
  # a typo rather than an old attempt.
  @earliest_exam_year 1990

  schema "student_exam_record" do
    field :application_number, :string
    field :application_password, :string
    field :date, :date
    field :score, :float
    field :percentile, :float
    field :all_india_rank, :integer
    field :category_rank, :integer
    field :sessions_applied, {:array, :integer}
    field :exam_email, :string
    field :exam_phone, :string
    field :exam_roll_no, :string
    field :exam_year, :integer

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
      :sessions_applied,
      :exam_email,
      :exam_phone,
      :exam_roll_no,
      :exam_year
    ])
    |> validate_required([:student_id, :application_number, :exam_id])
    |> trim_to_nil(:exam_email)
    |> trim_to_nil(:exam_phone)
    |> trim_to_nil(:exam_roll_no)
    # Deliberately loose - the only thing worth rejecting is a value that could
    # not reach a mailbox. The exam portal is the authority on what it accepts.
    |> validate_format(:exam_email, ~r/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/,
      message: "must be a valid email address"
    )
    # Digits only, as on `user.phone` - a value carrying "+91" or spaces has not
    # been normalized, and storing both forms makes the column unsearchable.
    |> validate_format(:exam_phone, ~r/\A\d+\z/, message: "must contain only digits")
    # The columns are varchar, which counts codepoints, so cap on codepoints -
    # otherwise a value in a non-Latin script passes here and fails on insert.
    |> validate_length(:exam_email, max: 255, count: :codepoints)
    |> validate_length(:exam_phone, max: 15, count: :codepoints)
    |> validate_length(:exam_roll_no, max: 50, count: :codepoints)
    # Registration for next year's exam opens in this one, so allow one year
    # ahead; the range exists to catch a mistyped or truncated year.
    |> validate_number(:exam_year,
      greater_than_or_equal_to: @earliest_exam_year,
      less_than_or_equal_to: Date.utc_today().year + 1
    )
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
