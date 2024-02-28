defmodule Dbservice.Programs.Program do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Groups.Group
  alias Dbservice.Batches.Batch
  alias Dbservice.Groups.GroupType
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  schema "program" do
    field :name, :string
    field :type, :string
    field :sub_type, :string
    field :mode, :string
    field :start_date, :date
    field :target_outreach, :integer
    field :product_used, :string
    field :donor, :string
    field :state, :string
    field :model, :string

    belongs_to :group, Group
    has_many :group_type, GroupType, foreign_key: :child_id, where: [type: "program"]
    many_to_many :batch, Batch, join_through: "batch_program", on_replace: :delete

    has_many :enrollment_record, EnrollmentRecord,
      foreign_key: :group_id,
      where: [group_type: "program"]

    timestamps()
  end

  @doc false
  def changeset(program, attrs) do
    program
    |> cast(attrs, [
      :name,
      :type,
      :sub_type,
      :mode,
      :start_date,
      :target_outreach,
      :product_used,
      :donor,
      :state,
      :model,
      :group_id
    ])
    |> validate_required([:name])
  end
end
