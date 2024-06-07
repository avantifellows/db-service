defmodule Dbservice.Statuses.Status do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Groups.Group

  schema "status" do
    field :title, :string

    has_many :group, Group, foreign_key: :child_id, where: [type: "status"]

    timestamps()
  end

  @doc false
  def changeset(auth_group, attrs) do
    auth_group
    |> cast(attrs, [
      :title
    ])
    |> validate_required([:title])
  end
end
