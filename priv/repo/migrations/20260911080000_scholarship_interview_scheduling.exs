defmodule Dbservice.Repo.Migrations.ScholarshipInterviewScheduling do
  use Ecto.Migration

  # af-scholarship Phase 2, interview track — scheduling (PRD §4.4–§4.5, §7.4;
  # decisions Q6–Q10 of the 2–3 Sep 2026 grilling).
  #
  # 1. scholarship_interviewers — the shared roster (add once, reuse across
  #    sessions). Removing an interviewer is a soft delete (`is_active = false`)
  #    so sessions that already ran keep their interviewer.
  #
  # 2. scholarship_interview_sessions — one interviewer, one date + start/END
  #    time window (Q6: students join at the start and wait to be called; no
  #    per-student slot), any number of mapped students (Q10: no min/max).
  #    Wall-clock IST is stored as-is (`date` + `time`), never converted.
  #    Status is DERIVED, never stored (Q9):
  #      emails_sent_at NULL               -> draft
  #      emails_sent_at set, end in future -> scheduled
  #      end time passed                   -> completed (auto-reverts if the
  #                                           session is moved to the future)
  #    The session number is not stored either: it is the position in
  #    (session_date, start_time) order (PRD §4.5, "auto-assigned, not editable").
  #    The briefing deck (PDF/PPTX, ≤ 20 MB, Q8) is an S3 object referenced from
  #    the row; emails cannot be sent until it is attached (PRD §4.5 hard gate).
  #
  # 3. scholarship_interview_session_students — the mapping. A student may appear
  #    in more than one session (e.g. re-scheduled after a no-show); the editor
  #    shows where they are already mapped.
  #
  # All additive -> deploy-safe. Apply on prod BEFORE the app deploy (the
  # responded_at lesson, 7 Aug 2026).
  def change do
    create table(:scholarship_interviewers) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :designation, :string
      add :is_active, :boolean, null: false, default: true
      add :created_by, references(:scholarship_reviewers, on_delete: :nilify_all)

      timestamps()
    end

    create index(:scholarship_interviewers, [:is_active])

    create table(:scholarship_interview_sessions) do
      add :cycle_id, references(:scholarship_cycles, on_delete: :delete_all), null: false

      add :interviewer_id, references(:scholarship_interviewers, on_delete: :restrict),
        null: false

      add :session_date, :date, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false

      add :briefing_deck_s3_key, :string
      add :briefing_deck_filename, :string
      add :briefing_deck_mime_type, :string
      add :briefing_deck_byte_size, :integer

      add :emails_sent_at, :utc_datetime
      add :feedback_form_sent_at, :utc_datetime

      add :created_by, references(:scholarship_reviewers, on_delete: :nilify_all)

      timestamps()
    end

    create index(:scholarship_interview_sessions, [:cycle_id, :session_date, :start_time])
    create index(:scholarship_interview_sessions, [:interviewer_id])

    create table(:scholarship_interview_session_students) do
      add :session_id,
          references(:scholarship_interview_sessions, on_delete: :delete_all),
          null: false

      add :application_id,
          references(:scholarship_applications, on_delete: :delete_all),
          null: false

      timestamps()
    end

    create unique_index(:scholarship_interview_session_students, [:session_id, :application_id])
    create index(:scholarship_interview_session_students, [:application_id])
  end
end
