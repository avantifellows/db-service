defmodule Dbservice.Repo.Migrations.ScholarshipSelectionCompletion do
  use Ecto.Migration

  # "Mark selection complete for Year 2026" — the one action that closes a
  # scholarship year (Phase 3 process walkthrough, Step 4; asked for by
  # Sanghamitra on 3 Oct 2026).
  #
  # Selection itself runs per interview session: finalizing a session locks its
  # Selected students and emails everyone in it. What no session can do is
  # close the YEAR — and until it is closed, a student who was shortlisted but
  # never interviewed, or waitlisted and never promoted, sits in that state
  # forever and is never told anything. Marking the year complete sweeps both
  # groups to `rejected` and sends them the same reject email.
  #
  # The flag belongs on the CYCLE: it is a fact about Year 2026, not about any
  # one session or application, and 2027 starts with it null again. Nullable
  # with no backfill — null means "this year is still open", which is true of
  # every row today.
  #
  # `selection_completed_by` records which staff row did it. This is a
  # once-only, irreversible action affecting every undecided applicant at once,
  # so the one question later is "who ran this, and when"; the per-student
  # trail is in scholarship_status_events as usual.
  def up do
    alter table(:scholarship_cycles) do
      add :selection_completed_at, :utc_datetime
      add :selection_completed_by, references(:scholarship_reviewers, on_delete: :nilify_all)
    end
  end

  def down do
    alter table(:scholarship_cycles) do
      remove :selection_completed_by
      remove :selection_completed_at
    end
  end
end
