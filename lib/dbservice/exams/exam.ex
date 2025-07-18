defmodule Dbservice.Exams.Exam do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "exam" do
    field :exam_id, :string
    field :name, :string
    field :cutoff_id, :string
    field :conducting_body, :string
    field :registration_deadline, :utc_datetime
    field :date, :utc_datetime
    field :cutoff, :map

    timestamps()
  end

  @doc false
  def changeset(exam, attrs) do
    exam
    |> cast(attrs, [
      :exam_id,
      :name,
      :cutoff_id,
      :conducting_body,
      :registration_deadline,
      :date,
      :cutoff
    ])
    |> validate_required([:name])
  end
end
