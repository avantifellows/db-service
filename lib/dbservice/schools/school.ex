defmodule Dbservice.Schools.School do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

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

    timestamps()
  end

  @doc false
  def changeset(school, attrs) do
    school
    |> cast(attrs, [:code, :name, :medium])
    |> validate_required([:code, :name])
  end
end
