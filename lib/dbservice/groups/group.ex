defmodule Dbservice.Groups.Group do
  use Ecto.Schema
  import Ecto.Changeset

  schema "group" do
    field :input_schema, :map
    field :locale, :string
    field :locale_data, :map

    timestamps()
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:input_schema, :locale, :locale_data])
    |> validate_required([:input_schema, :locale, :locale_data])
  end
end
