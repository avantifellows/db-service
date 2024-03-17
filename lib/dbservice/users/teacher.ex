defmodule Dbservice.Users.Teacher do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  schema "teacher" do
    field :designation, :string
    field :teacher_id, :string

    belongs_to :user, User

    has_many(:enrollment_record, EnrollmentRecord)

    timestamps()
  end

  @doc false
  def changeset(teacher, attrs) do
    teacher
    |> cast(attrs, [
      :user_id,
      :designation,
      :teacher_id
    ])
    |> validate_required([:user_id, :teacher_id])
  end
end
