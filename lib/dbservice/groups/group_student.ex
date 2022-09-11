defmodule Dbservice.Groups.GroupStudent do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Groups.Group
  alias Dbservice.Users.User

  schema "group_student" do
    field :program_date_of_joining, :utc_datetime
    field :program_student_language, :string
    belongs_to :group, Group
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(group_student, attrs) do
    group_student
    |> cast(attrs, [:program_date_of_joining, :program_student_language])
    |> validate_required([:program_date_of_joining, :program_student_language])
  end
end
