defmodule Dbservice.Groups.GroupType do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Groups.Group
  alias Dbservice.Programs.Program
  alias Dbservice.Batches.Batch

  schema "group_type" do
    field :type, :string
    field :child_id, :integer

    belongs_to :group, Group
    belongs_to :program, Program
    belongs_to :batch, Batch
    timestamps()
  end

  @doc false
  def changeset(group_type, attrs) do
    group_type
    |> cast(attrs, [
      :type,
      :child_id
    ])
    |> validate_required([:type, :child_id])
  end
end
