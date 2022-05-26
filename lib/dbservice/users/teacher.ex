defmodule Dbservice.Users.Teacher do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teacher" do
    field :designation, :string
    field :grade, :string
    field :subject, :string
    field :user_id, :id
    field :school_id, :id
    field :program_manager_id, :id

    timestamps()
  end

  @doc false
  def changeset(teacher, attrs) do
    teacher
    |> cast(attrs, [:designation, :subject, :grade])
    |> validate_required([:designation, :subject, :grade])
  end
end
