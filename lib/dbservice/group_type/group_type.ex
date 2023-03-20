defmodule Dbservice.GroupTypes.GroupType do
  @moduledoc false

  use Ecto.Schema
  alias Dbservice.Programs.Program
  alias Dbservice.Groups.Group

  import Ecto.Changeset

  schema "group" do
    field :name, :string
    field :input_schema, :map
    field :locale, :string
    field :locale_data, :map

    has_many :program, Program
    belongs_to :group_type, Group, foreign_key: :child_id

    timestamps()
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :name,
      :input_schema,
      :locale,
      :locale_data
    ])
    |> validate_required([:name])
  end
end
