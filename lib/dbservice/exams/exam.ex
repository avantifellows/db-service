defmodule Dbservice.Exams.Exam do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:exam_id, :string, autogenerate: false}
  @derive {Phoenix.Param, key: :exam_id}

  schema "exam" do
    field :name, :string
    field :registration_deadline, :utc_datetime
    field :date, :utc_datetime
    field :cutoff, :map
    field :conductingbody, :string

    timestamps()
  end

  @doc false
  def changeset(exam, attrs) do
    exam
    |> cast(attrs, [
      :name,
      :registration_deadline,
      :date,
      :cutoff,
      :conductingbody,
      :exam_id
    ])
    |> validate_required([:name, :exam_id])
    |> unique_constraint(:exam_id, name: :exam_exam_id_index)
  end
end
