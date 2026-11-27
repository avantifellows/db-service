defmodule Dbservice.Repo.Migrations.ScholarshipSessionStudentLinks do
  use Ecto.Migration

  # af-scholarship, interview track — the per-student Summary and Documents
  # links that go in the interviewer's schedule email (Program Team, 21 Sep
  # 2026, item 9).
  #
  # The reviewer pastes two links against each student while creating or
  # editing a session; the schedule email renders them as "View Summary" /
  # "View Documents" beside that student's name. They belong to the
  # (session, student) pair rather than to the application: the same student can
  # sit in two sessions, and a re-send of one session's email must carry the
  # links that session was given.
  #
  # Nullable on purpose — a session can be created before the links exist, and
  # the email simply omits the cell.
  #
  # Additive -> deploy-safe. Apply on prod BEFORE the app deploy.
  #
  # Renumbered from 20260921120000, which it shared with
  # create_blended_learning_mentor_mentee_mappings; Ecto refuses to run any
  # migration while two share a version. Idempotent because the environments
  # split on which one ran under that version: staging ran this one (columns
  # exist), prod ran Blended Learning (columns missing).
  def up do
    alter table(:scholarship_interview_session_students) do
      add_if_not_exists :summary_url, :text
      add_if_not_exists :documents_url, :text
    end
  end

  def down do
    alter table(:scholarship_interview_session_students) do
      remove_if_exists :summary_url, :text
      remove_if_exists :documents_url, :text
    end
  end
end
