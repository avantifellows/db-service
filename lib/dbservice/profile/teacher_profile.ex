defmodule Dbservice.Profiles.TeacherProfile do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Profiles.UserProfile
  alias Dbservice.Users.Teacher

  schema "teacher_profile" do
    field(:uuid, :string)
    field(:designation, :string)
    field(:subject, :string)
    field(:school, :string)
    # should i go with program_manager_id instead
    field(:program_manager, :string)
    field(:avg_rating, :decimal)
    # add plio, attendance, tests, teacher obs data later

    timestamps()

    belongs_to(:user_profile, UserProfile)
    belongs_to(:teacher, Teacher, foreign_key: :teacher_id)
  end

  def changeset(teacher_profile, attrs) do
    teacher_profile
    |> cast(attrs, [
      :teacher_id,
      :user_profile_id,
      :uuid,
      :designation,
      :subject,
      :school,
      :program_manager,
      :avg_rating
    ])
    |> validate_required([:user_profile_id, :teacher_id])
  end
end
