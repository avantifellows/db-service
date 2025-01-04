defmodule Dbservice.Exams.StudentExamRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Exams.Exam
  alias Dbservice.Users.Student

  schema "student_exam_record" do
    field :application_number, :string
    field :application_password, :string
    field :date, :date
    field :score, :float
    field :percentile, :float
    field :all_india_rank, :integer
    field :category_rank, :integer

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
      :category_rank
    ])
    |> validate_required([:student_id, :application_number, :exam_id])
  end
end
