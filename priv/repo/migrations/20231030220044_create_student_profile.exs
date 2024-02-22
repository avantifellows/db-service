defmodule Dbservice.Repo.Migrations.CreateStudentProfile do
  use Ecto.Migration

  def change do
    create table(:student_profile) do
      add :student_id, :string
      add :father_education_level, :string
      add :father_profession, :string
      add :mother_education_level, :string
      add :mother_profession, :string
      add :category, :string
      add :stream, :string
      add :physically_handicapped, :boolean
      add :annual_family_income, :string
      add :has_internet_access, :string
      add :took_test_atleast_once, :boolean
      add :took_class_atleast_once, :boolean
      add :total_number_of_tests, :integer
      add :total_number_of_live_classes, :integer
      add :attendance_in_classes_current_q1, :decimal
      add :attendance_in_classes_current_q2, :decimal
      add :attendance_in_classes_current_q3, :decimal
      add :attendance_in_classes_current_year, :decimal
      add :classes_activity_cohort, :string
      add :attendance_in_tests_current_q1, :decimal
      add :attendance_in_tests_current_q2, :decimal
      add :attendance_in_tests_current_q3, :decimal
      add :attendance_in_tests_current_year, :decimal
      add :tests_activity_cohort, :string
      add :performance_trend_in_fst, :string
      add :max_batch_score_in_latest_test, :integer
      add :average_batch_score_in_latest_test, :decimal
      add :tests_number_of_correct_questions, :integer
      add :tests_number_of_wrong_questions, :integer
      add :tests_number_of_skipped_questions, :integer
      add :user_profile_id, references(:user_profile, on_delete: :nothing)
      add :student_fkey_id, references(:student, on_delete: :nothing)

      timestamps()
    end

    create index(:student_profile, [:user_profile_id],
             name: "index_student_profile_on_user_profile_id"
           )

    create index(:student_profile, [:student_fkey_id],
             name: "index_student_profile_on_student_fkey_id"
           )
  end
end
