defmodule Dbservice.Groups.Group do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Programs.Program
  alias Dbservice.Groups.GroupType
  alias Dbservice.Schools.EnrollmentRecord

  schema "group" do
    field :name, :string
    field :input_schema, :map
    field :locale, :string
    field :locale_data, :map

    has_many :program, Program
    has_many :group_type, GroupType, foreign_key: :child_id, where: [type: "group"]
    has_many :group_fk_id, EnrollmentRecord, foreign_key: :group_id

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
