defmodule Dbservice.Repo.Migrations.AddSessionsAppliedToStudentExamRecord do
  use Ecto.Migration

  def up do
    # Some exams run the same paper more than once a year and a student applies
    # for a subset of those sittings - JEE Main's Session 1 and Session 2 are
    # the case we have. `exam_occurrence` describes the sittings themselves
    # (year, session, dates), but a record here is per student per exam, and
    # which sittings the student applied for is a fact about the application,
    # not about the sitting. So it is stored here as the session numbers.
    #
    # Nullable with no default: rows that predate this, and exams that run
    # once, simply have nothing to say. Adding a nullable column with no
    # default is metadata-only, so this does not scan the table.
    alter table(:student_exam_record) do
      add :sessions_applied, {:array, :integer}
    end
  end

  def down do
    alter table(:student_exam_record) do
      remove :sessions_applied
    end
  end
end
