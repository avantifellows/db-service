defmodule Dbservice.Programs.Program do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Batches.Batch
  alias Dbservice.Groups.Group
  alias Dbservice.GroupTypes.GroupType

  schema "program" do
    field :name, :string
    field :program_type, :string
    field :program_sub_type, :string
    field :program_mode, :string
    field :program_start_date, :date
    field :program_target_outreach, :integer
    field :program_product_used, :string
    field :program_donor, :string
    field :program_state, :string
    field :program_model, :string

    many_to_many :batch, Batch, join_through: "batch_program", on_replace: :delete
    belongs_to :group, GroupType
    belongs_to :group_type, Group, foreign_key: :child_id

    timestamps()
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :name,
      :program_type,
      :program_sub_type,
      :program_mode,
      :program_start_date,
      :program_target_outreach,
      :program_product_used,
      :program_donor,
      :program_state,
      :program_model,
      :group_id
    ])
    |> validate_required([:name])
  end
end
