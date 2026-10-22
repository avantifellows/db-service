defmodule Dbservice.Exams.StudentExamRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Exams.Exam
  alias Dbservice.Users.Student

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
  end
end
