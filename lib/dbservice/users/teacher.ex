defmodule Dbservice.Users.Teacher do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users
  alias Dbservice.Schools

  schema "teacher" do
    field :designation, :string
    field :grade, :string
    field :subject, :string
    belongs_to :user, Users.User
    belongs_to :school, Schools.School
    belongs_to :program_manager, Users.User

    timestamps()
  end

  @doc false
  def changeset(teacher, attrs) do
    teacher
    |> cast(attrs, [:user_id, :school_id, :program_manager_id, :designation, :subject, :grade])
    |> validate_required([:user_id, :school_id])
  end
end
