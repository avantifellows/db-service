defmodule Dbservice.Users.Teacher do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Schools.School

  schema "teacher" do
    field :designation, :string
    field :grade, :string
    field :subject, :string
    field :teacher_id, :string
    belongs_to :user, User
    belongs_to :school, School
    belongs_to :program_manager, User

    timestamps()
  end

  @doc false
  def changeset(teacher, attrs) do
    teacher
    |> cast(attrs, [
      :user_id,
      :school_id,
      :program_manager_id,
      :designation,
      :subject,
      :grade,
      :teacher_id
    ])
    |> validate_required([:user_id])
  end
end
