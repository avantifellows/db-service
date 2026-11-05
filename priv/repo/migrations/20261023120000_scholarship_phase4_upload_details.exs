defmodule Dbservice.Repo.Migrations.ScholarshipPhase4UploadDetails do
  use Ecto.Migration

  # Phase 4 slice 9 — the uploads that are neither a scorecard nor a bill
  # (PRD §19: required forms, internship and placement details, photographs).
  #
  # `scholarship_student_uploads` already holds the row and
  # `scholarship_attachments` already holds its files, both from the
  # foundations migration (20261022150000). What is missing is the handful of
  # facts a scholar types ALONGSIDE the file, and they differ per kind:
  #
  #   form        nothing beyond which form it is, which `title` already says
  #   internship  organisation, role, internship or placement, start, end,
  #               stipend
  #   photo       caption and the day it was taken
  #
  # One jsonb column rather than six nullable ones, following ADR 0003 in the
  # app: a field is promoted to its own column when something queries, filters
  # or decides on it, and none of these are. They are shown back to the scholar
  # and read by the programme team, nothing more. A column per field would also
  # mean a migration every time the team asks for one more question.
  def change do
    alter table(:scholarship_student_uploads) do
      add :details, :map, null: false, default: %{}
    end
  end
end
