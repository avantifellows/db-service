defmodule Dbservice.Repo.Migrations.AddExamDetailsToStudentExamRecord do
  use Ecto.Migration

  def up do
    # A student registers for an exam with contact details and a roll number
    # that are the exam portal's, not ours - the email and phone on `user` are
    # how Avanti reaches the student, which is often a parent's number, and the
    # roll number is issued per exam. Without these, a result or an admit card
    # can't be traced back from the exam body's records.
    #
    # All four are nullable: we only learn them once registration closes, and
    # the rows already in the table predate them. Adding nullable columns with
    # no default is metadata-only, so this does not scan the table.
    alter table(:student_exam_record) do
      add :exam_email, :string, size: 255
      add :exam_phone, :string, size: 15
      add :exam_roll_no, :string, size: 50
      # The year the exam took place. `date` is the exam date, but most of what
      # ops holds for past attempts is just a year, and a year is what a result
      # is reported against - so it is its own column rather than something
      # derived from a date we may never get.
      add :exam_year, :integer
    end
  end

  def down do
    alter table(:student_exam_record) do
      remove :exam_year
      remove :exam_roll_no
      remove :exam_phone
      remove :exam_email
    end
  end
end
