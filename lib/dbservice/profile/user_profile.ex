defmodule Dbservice.Profiles.UserProfile do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Profiles.StudentProfile
  alias Dbservice.Profiles.TeacherProfile

  schema "user_profile" do
    field(:logged_in_atleast_once, :boolean)
    field(:latest_session_accessed, :string)

    timestamps()

    belongs_to(:user, User, foreign_key: :user_id)
    has_one(:student_profile, StudentProfile)
    has_one(:teacher_profile, TeacherProfile)
  end

  def changeset(user_profile, attrs) do
    user_profile
    |> cast(attrs, [
      :user_id,
      :logged_in_atleast_once,
      :latest_session_accessed
    ])
    |> validate_required([:user_id])
  end
end
