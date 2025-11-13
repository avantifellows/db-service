defmodule Dbservice.Branches.Branch do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "branch" do
    field :branch_id, :string
    field :parent_branch, :string
    field :name, :string
    field :duration, :integer

    has_many :cutoffs, Dbservice.Cutoffs.Cutoff

    timestamps()
  end

  @doc false
  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [
      :branch_id,
      :parent_branch,
      :name,
      :duration
    ])
    |> validate_required([:branch_id, :name])
    |> unique_constraint(:branch_id)
  end
end
