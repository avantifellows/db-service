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
  def change do
    alter table(:scholarship_interview_session_students) do
      add :summary_url, :text
      add :documents_url, :text
    end
  end
end
