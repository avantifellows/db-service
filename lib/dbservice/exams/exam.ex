defmodule Dbservice.Exams.Exam do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "exam" do
    field :name, :string
    field :counselling_body, :string
    field :type, :string

    has_many :exam_occurrences, Dbservice.Exams.ExamOccurrence

    timestamps()
  end

  @doc false
  def changeset(exam, attrs) do
    exam
    |> cast(attrs, [
      :name,
      :counselling_body,
      :type
    ])
    |> validate_required([:name])
  end
end
