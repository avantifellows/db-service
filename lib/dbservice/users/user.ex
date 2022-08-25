defmodule Dbservice.Users.User do
  @moduledoc false

  use Ecto.Schema
  use Pow.Ecto.Schema

  import Ecto.Changeset

  alias Dbservice.Sessions.SessionOccurence
  alias Dbservice.Batches.Batch

  schema "user" do
    field :address, :string
    field :city, :string
    field :district, :string
    field :email, :string
    field :first_name, :string
    field :gender, :string
    field :last_name, :string
    field :phone, :string
    field :pincode, :string
    field :role, :string
    field :state, :string
    field :password_hash, :string
    field :password_confirmation, :string

    pow_user_fields()
    timestamps()

    many_to_many :sessions, SessionOccurence, join_through: "user_session", on_replace: :delete
    many_to_many :batches, Batch, join_through: "batch_user", on_replace: :delete
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :first_name,
      :last_name,
      :email,
      :phone,
      :gender,
      :address,
      :city,
      :district,
      :state,
      :pincode,
      :role,
      :password_hash,
      :password_confirmation
    ])
    |> validate_required([:first_name, :last_name, :email, :phone, :password_hash])
  end

  @spec changeset_update_batches(
          {map, any}
          | %{
              :__struct__ => atom | %{:__changeset__ => any, optional(any) => any},
              optional(any) => any
            },
          any
        ) :: Ecto.Changeset.t()
  def changeset_update_batches(user, batches) do
    user
    |> change()
    |> put_assoc(:batches, batches)
  end
end
