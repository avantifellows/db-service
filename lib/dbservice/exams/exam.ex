defmodule Dbservice.Exams.Exam do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "exam" do
    field :name, :string
    field :registration_deadline, :utc_datetime
    field :date, :utc_datetime,
    field :cutoff, :map

    timestamps()
  end

  @doc false
  def changeset(exam, attrs) do
    exam
    |> cast(attrs, [
      :name,
      :registration_deadline,
      :date,
      :cutoff
    ])
    |> validate_required([:name])
  end
end
