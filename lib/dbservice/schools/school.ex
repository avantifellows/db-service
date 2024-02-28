defmodule Dbservice.Schools.School do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  schema "school" do
    field :code, :string
    field :name, :string
    field :udise_code, :string
    field :type, :string
    field :category, :string
    field :region, :string
    field :state_code, :string
    field :state, :string
    field :district_code, :string
    field :district, :string
    field :block_code, :string
    field :block_name, :string
    field :board, :string
    field :board_medium, :string

    has_many :group_fk, EnrollmentRecord, foreign_key: :group_id, where: [group_type: "school"]

    timestamps()
  end

  @doc false
  def changeset(school, attrs) do
    school
    |> cast(attrs, [
      :code,
      :name,
      :udise_code,
      :type,
      :category,
      :region,
      :state_code,
      :state,
      :district_code,
      :district,
      :block_code,
      :block_name,
      :board,
      :board_medium
    ])
    |> validate_required([:code, :name])
  end
end
