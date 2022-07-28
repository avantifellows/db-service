defmodule Dbservice.Schools.School do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "school" do
    field :code, :string
    field :medium, :string
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(school, attrs) do
    school
    |> cast(attrs, [:code, :name, :medium])
    |> validate_required([:code, :name])
  end
end
