defmodule Dbservice.Exams.StudentExamRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Exams.Exam
  alias Dbservice.Users.Student

  schema "student_exam_record" do
    field :application_number, :string
    field :application_password, :string
    field :date, :utc_datetime
    field :score, :float
    field :rank, :integer

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
      :rank
    ])
    |> validate_required([:student_id, :exam_id])
  end
end
