defmodule Dbservice.Users.Student do
  use Ecto.Schema
  import Ecto.Changeset

  schema "student" do
    field :category, :string
    field :father_name, :string
    field :father_phone, :string
    field :mother_name, :string
    field :mother_phone, :string
    field :stream, :string
    field :uuid, :string
    field :user_id, :id
    field :group_id, :id

    timestamps()
  end

  @doc false
  def changeset(student, attrs) do
    student
    |> cast(attrs, [:uuid, :father_name, :father_phone, :mother_name, :mother_phone, :category, :stream])
    |> validate_required([:uuid, :father_name, :father_phone, :mother_name, :mother_phone, :category, :stream])
  end
end
