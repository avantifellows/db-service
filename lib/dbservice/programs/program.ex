defmodule Dbservice.Programs.Program do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Products.Product
  alias Dbservice.Groups.Group
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  schema "program" do
    field :name, :string
    field :target_outreach, :integer
    field :donor, :string
    field :state, :string
    field :model, :string
    field :is_current, :boolean, default: true

    belongs_to :product, Product
    has_many :group, Group, foreign_key: :child_id, where: [type: "program"]

    has_many :enrollment_record, EnrollmentRecord,
      foreign_key: :group_id,
      where: [group_type: "program"]

    timestamps()
  end

  @doc false
  def changeset(program, attrs) do
    program
    |> cast(attrs, [
      :name,
      :target_outreach,
      :donor,
      :state,
      :product_id,
      :model,
      :is_current
    ])
    |> validate_required([:name])
  end
end
