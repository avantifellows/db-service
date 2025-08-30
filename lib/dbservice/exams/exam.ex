defmodule Dbservice.Exams.Exam do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "exam" do
    field :exam_name, :string
    field :counselling_body, :string
    field :type, :string

    has_many :exam_occurrences, Dbservice.Exams.ExamOccurrence

    timestamps()
  end

  @doc false
  def changeset(exam, attrs) do
    exam
    |> cast(attrs, [
      :exam_name,
      :counselling_body,
      :type
    ])
    |> validate_required([:exam_name])
  end
end
