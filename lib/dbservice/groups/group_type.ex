defmodule Dbservice.Groups.GroupType do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "group_type" do
    field :type, :string
    field :child_id, :integer

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
