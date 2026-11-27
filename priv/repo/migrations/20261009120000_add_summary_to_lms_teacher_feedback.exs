defmodule Dbservice.Repo.Migrations.AddSummaryToLmsTeacherFeedback do
  use Ecto.Migration

  # LLM summary of one teacher's feedback form, written by the etl-next
  # teacher-feedback-summaries flow after the round closes. The fingerprint is a
  # hash of the answers it was built from, so unchanged rounds aren't redone.
  def change do
    alter table(:lms_teacher_feedback) do
      add(:summary, :map)
      add(:summary_prompt_version, :string, size: 50)
      add(:summary_fingerprint, :string, size: 64)
      add(:summary_generated_at, :naive_datetime)
    end
  end
end
