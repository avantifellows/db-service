defmodule Dbservice.Languages.Language do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "language" do
    field :name, :string
    field :code, :string

    timestamps()
  end

  @doc false
  def changeset(language, attrs) do
    language
    |> cast(attrs, [
      :name,
      :code
    ])
    |> validate_required([:name, :code])
  end
end
