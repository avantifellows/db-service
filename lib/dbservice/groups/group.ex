defmodule Dbservice.Groups.Group do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Groups.GroupType
  alias Dbservice.Programs.Program

  schema "group" do
    field :name, :string
    field :input_schema, :map
    field :locale, :string
    field :locale_data, :map

    belongs_to :group_type, GroupType, foreign_key: :child_id
    has_many :program, Program

    timestamps()
  end

  @doc false
  def changeset(group_type, attrs) do
    group_type
    |> cast(attrs, [
      :name,
      :input_schema,
      :locale,
      :locale_data
    ])
    |> validate_required([:name])
  end
end
