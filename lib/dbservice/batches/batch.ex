defmodule Dbservice.Batches.Batch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Programs.Program
  alias Dbservice.Groups.Group
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Sessions.SessionSchedule
  alias Dbservice.Groups.AuthGroup

  schema "batch" do
    field :name, :string
    field :contact_hours_per_week, :integer
    field :batch_id, :string
    field :parent_id, :integer
    field :start_date, :date
    field :end_date, :date

    belongs_to :program, Program
    belongs_to :auth_group, AuthGroup
    has_many :group, Group, foreign_key: :child_id, where: [type: "batch"]

    has_many :enrollment_record, EnrollmentRecord,
      foreign_key: :group_id,
      where: [group_type: "batch"]

    has_one :session_schedule, SessionSchedule

    timestamps()
  end

  @doc false
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [
      :name,
      :contact_hours_per_week,
      :batch_id,
      :parent_id,
      :start_date,
      :end_date,
      :program_id,
      :auth_group_id
    ])
    |> validate_required([:name])
  end
end
