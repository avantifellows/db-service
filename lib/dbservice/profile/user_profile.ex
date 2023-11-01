defmodule Dbservice.Profiles.UserProfile do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Profiles.StudentProfile
  alias Dbservice.Profiles.TeacherProfile

  schema "user_profile" do
    field(:full_name, :string)
    field(:email, :string)
    field(:date_of_birth, :date)
    field(:gender, :string)
    field(:role, :string)
    field(:state, :string)
    field(:country, :string)
    field(:current_grade, :string)
    field(:current_program, :string)
    field(:current_batch, :string)
    field(:logged_in_atleast_once, :boolean)
    field(:first_session_accessed, :string)
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
      :full_name,
      :email,
      :date_of_birth,
      :gender,
      :role,
      :state,
      :country,
      :current_grade,
      :current_program,
      :current_batch,
      :logged_in_atleast_once,
      :first_session_accessed,
      :latest_session_accessed
    ])
    |> validate_required([:user_id])
  end
end
