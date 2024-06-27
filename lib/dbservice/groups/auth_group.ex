defmodule Dbservice.Groups.AuthGroup do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Batches.Batch
  alias Dbservice.Groups.Group
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  schema "auth_group" do
    field :name, :string
    field :input_schema, :map
    field :locale, :string
    field :locale_data, :map

    has_many :batch, Batch
    has_many :group, Group, foreign_key: :child_id, where: [type: "auth-group"]

    has_many :enrollment_record, EnrollmentRecord,
      foreign_key: :group_type_id,
      where: [group: "auth-group"]

    timestamps()
  end

  @doc false
  def changeset(auth_group, attrs) do
    auth_group
    |> cast(attrs, [
      :name,
      :input_schema,
      :locale,
      :locale_data
    ])
    |> validate_required([:name])
  end
end
