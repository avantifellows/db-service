defmodule Dbservice.Batches.Batch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Programs.Program
  alias Dbservice.Groups.GroupType

  schema "batch" do
    field :name, :string

    belongs_to :group_type, GroupType, foreign_key: :child_id
    many_to_many :program, Program, join_through: "batch_program", on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [
      :name
    ])
    |> validate_required([:name])
  end
end
