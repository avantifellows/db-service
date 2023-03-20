defmodule Dbservice.Batches.Batch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Programs.Program
  alias Dbservice.GroupTypes.GroupType

  schema "batch" do
    field :name, :string
    field :contact_hours_per_week, :integer

    many_to_many :program, Program, join_through: "batch_program", on_replace: :delete
    belongs_to :group_type, GroupType, foreign_key: :child_id

    timestamps()
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :name,
      :contact_hours_per_week
    ])
    |> validate_required([:name])
  end
end
