defmodule Dbservice.Users.Teacher do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Profiles.TeacherProfile
  alias Dbservice.Subjects.Subject

  schema "teacher" do
    field :designation, :string
    field :teacher_id, :string
    field :is_af_teacher, :boolean

    belongs_to :user, User
    has_one :teacher_profile, TeacherProfile
    belongs_to :subject, Subject

    timestamps()
  end

  @doc false
  def changeset(teacher, attrs) do
    teacher
    |> cast(attrs, [
      :user_id,
      :designation,
      :teacher_id,
      :subject_id,
      :is_af_teacher
    ])
    |> validate_required([:user_id, :teacher_id])
  end
end
