defmodule Dbservice.Profiles.StudentProfile do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Profiles.UserProfile
  alias Dbservice.Users.Student

  schema "student_profile" do
    field(:student_id, :string)
    field(:took_test_atleast_once, :boolean)
    field(:took_class_atleast_once, :boolean)
    field(:total_number_of_tests, :integer)
    field(:total_number_of_live_classes, :integer)
    field(:attendance_in_classes_current_year, {:array, :decimal})
    field(:classes_activity_cohort, :string)
    field(:attendance_in_tests_current_year, {:array, :decimal})
    field(:tests_activity_cohort, :string)
    field(:performance_trend_in_fst, :string)
    field(:max_batch_score_in_latest_test, :integer)
    field(:average_batch_score_in_latest_test, :decimal)
    field(:tests_number_of_correct_questions, :integer)
    field(:tests_number_of_wrong_questions, :integer)
    field(:tests_number_of_skipped_questions, :integer)
    # add plio data later

    timestamps()

    belongs_to(:user_profile, UserProfile)
    belongs_to(:student, Student, foreign_key: :student_fk)
  end

  def changeset(student_profile, attrs) do
    student_profile
    |> cast(attrs, [
      :student_fk,
      :user_profile_id,
      :student_id,
      :took_test_atleast_once,
      :took_class_atleast_once,
      :total_number_of_tests,
      :total_number_of_live_classes,
      :attendance_in_classes_current_year,
      :classes_activity_cohort,
      :attendance_in_tests_current_year,
      :tests_activity_cohort,
      :performance_trend_in_fst,
      :max_batch_score_in_latest_test,
      :average_batch_score_in_latest_test,
      :tests_number_of_correct_questions,
      :tests_number_of_wrong_questions,
      :tests_number_of_skipped_questions
    ])
    |> validate_required([:user_profile_id, :student_fk])
  end
end
