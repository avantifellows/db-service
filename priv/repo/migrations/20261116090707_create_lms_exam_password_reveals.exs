defmodule Dbservice.Repo.Migrations.CreateLmsExamPasswordReveals do
  use Ecto.Migration

  # One row each time an AF LMS user decrypts a Student's exam-portal password.
  # db-service owns the schema; af_lms writes the rows directly and nothing here
  # reads them. There is no schema/context here.
  #
  # The exam record id carries no FK: removing a registration in the Exams tab
  # deletes its student_exam_record row, and the reveals of it must survive that.
  def change do
    create table(:lms_exam_password_reveals) do
      add :student_id, references(:student, on_delete: :nothing), null: false
      add :student_exam_record_id, :bigint, null: false
      add :exam_id, references(:exam, on_delete: :nothing), null: false
      add :viewer_email, :text, null: false
      add :viewer_role, :text, null: false

      timestamps(default: fragment("now()"), null: false, updated_at: false)
    end

    create index(:lms_exam_password_reveals, [:student_id, :inserted_at])
    create index(:lms_exam_password_reveals, [:viewer_email, :inserted_at])

    # af_lms lower-cases the email it writes; a mixed-case or blank one would
    # split one viewer's history in two or hide who looked.
    create constraint(:lms_exam_password_reveals, :lms_exam_password_reveals_viewer_check,
             check: """
             viewer_email ~ '[^[:space:]]' AND viewer_email = lower(viewer_email) AND
             viewer_role ~ '[^[:space:]]'
             """
           )

    execute(
      """
      CREATE FUNCTION lms_protect_exam_password_reveals()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Exam password reveals are append-only'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION lms_protect_exam_password_reveals()"
    )

    execute(
      """
      CREATE TRIGGER lms_exam_password_reveals_append_only
      BEFORE UPDATE OR DELETE ON lms_exam_password_reveals
      FOR EACH ROW EXECUTE FUNCTION lms_protect_exam_password_reveals()
      """,
      "DROP TRIGGER lms_exam_password_reveals_append_only ON lms_exam_password_reveals"
    )
  end
end
