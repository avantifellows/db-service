defmodule Dbservice.FormSchemas.FormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "form_schema" do
    field :name, :string
    field :attributes, :map

    timestamps()
  end

  @doc false
  def changeset(form_schema, attrs) do
    form_schema
    |> cast(attrs, [
      :name,
      :attributes
    ])
    |> validate_required([:name])
  end
end
