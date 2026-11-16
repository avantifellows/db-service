defmodule Dbservice.Repo.Migrations.AddApplicationPasswordCiphertextToStudentExamRecord do
  use Ecto.Migration

  # The exam-portal password moves from plaintext to an AWS KMS ciphertext that
  # AF LMS produces and alone can decrypt. The plaintext column stays until the
  # backfill has re-encrypted every existing value; a later migration drops it.
  def change do
    alter table(:student_exam_record) do
      add :application_password_ciphertext, :text
    end
  end
end
