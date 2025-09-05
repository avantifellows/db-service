defmodule Dbservice.Exams.ExamOccurrence do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "exam_occurrence" do
    field :year, :integer
    field :exam_session, :integer
    field :registration_end_date, :string
    field :session_date, :string

    belongs_to :exam, Dbservice.Exams.Exam
    has_many :cutoffs, Dbservice.Cutoffs.Cutoff

    timestamps()
  end

  @doc false
  def changeset(exam_occurrence, attrs) do
    exam_occurrence
    |> cast(attrs, [
      :exam_id,
      :year,
      :exam_session,
      :registration_end_date,
      :session_date
    ])
    |> validate_required([:exam_id, :year])
    |> foreign_key_constraint(:exam_id)
  end
end
