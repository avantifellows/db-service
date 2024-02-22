defmodule Dbservice.Profiles.StudentProfile do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Profiles.UserProfile
  alias Dbservice.Users.Student

  schema "student_profile" do
    field(:student_id, :string)
    field(:father_education_level, :string)
    field(:father_profession, :string)
    field(:mother_education_level, :string)
    field(:mother_profession, :string)
    field(:category, :string)
    field(:stream, :string)
    field(:physically_handicapped, :boolean)
    field(:annual_family_income, :string)
    field(:has_internet_access, :string)
    field(:took_test_atleast_once, :boolean)
    field(:took_class_atleast_once, :boolean)
    field(:total_number_of_tests, :integer)
    field(:total_number_of_live_classes, :integer)
    field(:attendance_in_classes_current_q1, :decimal)
    field(:attendance_in_classes_current_q2, :decimal)
    field(:attendance_in_classes_current_q3, :decimal)
    field(:attendance_in_classes_current_year, :decimal)
    field(:classes_activity_cohort, :string)
    field(:attendance_in_tests_current_q1, :decimal)
    field(:attendance_in_tests_current_q2, :decimal)
    field(:attendance_in_tests_current_q3, :decimal)
    field(:attendance_in_tests_current_year, :decimal)
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
    belongs_to(:student, Student, foreign_key: :student_fkey_id)
  end

  def changeset(student_profile, attrs) do
    student_profile
    |> cast(attrs, [
      :student_id,
      :student_fkey_id,
      :user_profile_id,
      :father_education_level,
      :father_profession,
      :mother_education_level,
      :mother_profession,
      :category,
      :stream,
      :physically_handicapped,
      :annual_family_income,
      :has_internet_access,
      :took_test_atleast_once,
      :took_class_atleast_once,
      :total_number_of_tests,
      :total_number_of_live_classes,
      :attendance_in_classes_current_q1,
      :attendance_in_classes_current_q2,
      :attendance_in_classes_current_q3,
      :attendance_in_classes_current_year,
      :classes_activity_cohort,
      :attendance_in_tests_current_q1,
      :attendance_in_tests_current_q2,
      :attendance_in_tests_current_q3,
      :attendance_in_tests_current_year,
      :tests_activity_cohort,
      :performance_trend_in_fst,
      :max_batch_score_in_latest_test,
      :average_batch_score_in_latest_test,
      :tests_number_of_correct_questions,
      :tests_number_of_wrong_questions,
      :tests_number_of_skipped_questions
    ])
    |> validate_required([:user_profile_id, :student_fkey_id])
  end
end
