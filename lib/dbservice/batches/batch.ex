defmodule Dbservice.Batches.Batch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Programs.Program
  alias Dbservice.Groups.GroupType
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  schema "batch" do
    field :name, :string
    field :contact_hours_per_week, :integer

    has_many :group_type, GroupType, foreign_key: :child_id, where: [type: "batch"]

    has_many :enrollment_record, EnrollmentRecord,
      foreign_key: :grouping_id,
      where: [grouping_type: "batch"]

    many_to_many :program, Program, join_through: "batch_program", on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [
      :name,
      :contact_hours_per_week
    ])
    |> validate_required([:name])
  end
end
