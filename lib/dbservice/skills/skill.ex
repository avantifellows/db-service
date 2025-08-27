defmodule Dbservice.Skills.Skill do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "skill" do
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [
      :name
    ])
    |> validate_required([:name])
  end
end
