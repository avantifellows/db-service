defmodule Dbservice.FormSchemas.FormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Sessions.Session

  schema "form_schema" do
    field(:name, :string)
    field(:meta_data, :map)
    field(:attributes, :map)

    timestamps()

    has_many(:session, Session)
  end

  @doc false
  def changeset(form_schema, attrs) do
    form_schema
    |> cast(attrs, [
      :name,
      :attributes,
      :meta_data
    ])
    |> validate_required([:name])
  end
end
