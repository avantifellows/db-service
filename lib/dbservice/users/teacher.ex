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
    field :exit_date, :date

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
      :is_af_teacher,
      :exit_date
    ])
    |> validate_required([:user_id])
    |> unique_constraint(:teacher_id, name: :teacher_teacher_id_unique)
  end
end
