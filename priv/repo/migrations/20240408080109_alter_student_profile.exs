defmodule Dbservice.Repo.Migrations.AlterStudentProfile do
  use Ecto.Migration

  def change do
    alter table(:student_profile) do
      remove :father_education_level
      remove :father_profession
      remove :mother_education_level
      remove :mother_profession
      remove :category
      remove :stream
      remove :physically_handicapped
      remove :annual_family_income
      remove :has_internet_access
      remove :attendance_in_classes_current_q1
      remove :attendance_in_classes_current_q2
      remove :attendance_in_classes_current_q3
      remove :attendance_in_classes_current_year
      add :attendance_in_classes_current_year, {:array, :decimal}
      remove :attendance_in_tests_current_q1
      remove :attendance_in_tests_current_q2
      remove :attendance_in_tests_current_q3
      remove :attendance_in_tests_current_year
      add :attendance_in_tests_current_year, {:array, :decimal}
    end

    rename table(:student_profile), :student_fkey_id, to: :student_fk

    drop index(:student_profile, [:student_fkey_id],
           name: "index_student_profile_on_student_fkey_id"
         )

    create index(:student_profile, [:student_fk], name: "index_student_profile_on_student_fk")
  end
end
