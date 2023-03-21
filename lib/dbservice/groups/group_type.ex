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

    has_many :group, Group
    has_many :program, Program
    has_many :batch, Batch

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
