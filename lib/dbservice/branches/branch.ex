defmodule Dbservice.Branches.Branch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "branch" do
    field :branch_id, :string
    field :name, :string
    field :duration, :integer

    belongs_to :parent, __MODULE__, foreign_key: :parent_branch_id
    has_many :children, __MODULE__, foreign_key: :parent_branch_id

    has_many :cutoffs, Dbservice.Cutoffs.Cutoff

    timestamps()
  end

  @doc false
  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [
      :branch_id,
      :parent_branch_id,
      :name,
      :duration
    ])
    |> validate_required([:branch_id, :name])
    |> unique_constraint(:branch_id)
    |> foreign_key_constraint(:parent_branch_id)
  end
end
