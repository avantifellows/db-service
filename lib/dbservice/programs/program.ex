defmodule Dbservice.Programs.Program do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Batches.Batch
  alias Dbservice.StudentPrograms.StudentProgram

  schema "program" do
    field :name, :string
    field :type, :string
    field :sub_type, :string
    field :mode, :string
    field :start_date, :date
    field :target_outreach, :integer
    field :products_used, :string
    field :donor, :string
    field :state, :string
    field :engagement_level, :string

    timestamps()

    has_many :student_program, StudentProgram
    has_many :batch, Batch
  end

  def changeset(program, attrs) do
    program
    |> cast(attrs, [
      :name,
      :type,
      :sub_type,
      :mode,
      :start_date,
      :target_outreach,
      :products_used,
      :donor,
      :state,
      :engagement_level
    ])
    |> validate_required([:name])
  end
end
