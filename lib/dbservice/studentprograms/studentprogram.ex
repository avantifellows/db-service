defmodule Dbservice.StudentPrograms.StudentProgram do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Programs.Program
  alias Dbservice.Users.User
  alias Dbservice.Users.Student

  schema "student_program" do
    field :is_high_touch, :string

    timestamps()

    belongs_to :program, Program
    belongs_to :user, User
    belongs_to :student, Student
    belongs_to :program_manager, User
  end

  def changeset(program, attrs) do
    program
    |> cast(attrs, [:is_high_touch, :student_id, :program_id, :program_manager_id])
    |> validate_required([:is_high_touch])
  end
end
