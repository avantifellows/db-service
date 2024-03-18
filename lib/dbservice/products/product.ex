defmodule Dbservice.Products.Product do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "product" do
    field :name, :string
    field :mode, :string
    field :model, :string
    field :tech_modules, :string
    field :type, :string
    field :led_by, :string
    field :goal, :string
    field :code, :string

    has_many :group, Group, foreign_key: :child_id, where: [type: "product"]

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :name,
      :mode,
      :model,
      :tech_modules,
      :type,
      :led_by,
      :goal,
      :code
    ])
    |> validate_required([:name])
  end
end
