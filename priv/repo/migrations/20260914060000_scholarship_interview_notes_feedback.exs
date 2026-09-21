defmodule Dbservice.Repo.Migrations.ScholarshipInterviewNotesFeedback do
  use Ecto.Migration

  # af-scholarship Phase 2, interview track — slice 3: post-interview notes +
  # the in-portal interviewer feedback form (PRD §4.6, §7.4; decisions Q9, Q11
  # of the 2–3 Sep 2026 grilling).
  #
  # 1. scholarship_interview_notes — the reviewer's post-interview note per
  #    (session, student): one tag (taxonomy still a Program-Team decision, so a
  #    plain string) + free text. Surfaces on the student's Application Review
  #    record, not just the session. One row per student per session; a re-save
  #    updates it.
  #
  # 2. scholarship_interview_feedback — the interviewer's answers from the
  #    tokenised feedback form (Zoho fields 4–8 kept verbatim, Q11): neediness
  #    1–5, ambition yes/maybe/no, recommendation select/waitlist/reject (a
  #    recommendation only — never moves the application status; Phase 3
  #    decides), interview score 10–100, optional remarks. One row per student
  #    per session; a resubmission updates it. "X of Y submitted" = rows /
  #    mapped students.
  #
  # 3. scholarship_interview_sessions.feedback_token — the per-session secret in
  #    the form link the interviewer receives (no login; the link scopes the form
  #    to that session's students only). Minted on the first "Send feedback form".
  #
  # All additive -> deploy-safe. Apply on prod BEFORE the app deploy.
  def change do
    create table(:scholarship_interview_notes) do
      add :session_id,
          references(:scholarship_interview_sessions, on_delete: :delete_all),
          null: false

      add :application_id,
          references(:scholarship_applications, on_delete: :delete_all),
          null: false

      add :tag, :string
      add :note_text, :text
      add :created_by, references(:scholarship_reviewers, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:scholarship_interview_notes, [:session_id, :application_id])
    create index(:scholarship_interview_notes, [:application_id])

    create table(:scholarship_interview_feedback) do
      add :session_id,
          references(:scholarship_interview_sessions, on_delete: :delete_all),
          null: false

      add :application_id,
          references(:scholarship_applications, on_delete: :delete_all),
          null: false

      add :neediness_score, :integer, null: false
      add :ambition_confidence, :string, null: false
      add :recommendation, :string, null: false
      add :interview_score, :integer, null: false
      add :remarks, :text

      timestamps()
    end

    create unique_index(:scholarship_interview_feedback, [:session_id, :application_id])
    create index(:scholarship_interview_feedback, [:application_id])

    alter table(:scholarship_interview_sessions) do
      add :feedback_token, :string
    end

    create unique_index(:scholarship_interview_sessions, [:feedback_token])
  end
end
