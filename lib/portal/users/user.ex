defmodule Portal.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :phone, :string

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :email, :phone])
    |> validate_required([:first_name, :last_name, :email, :phone])
  end
end
