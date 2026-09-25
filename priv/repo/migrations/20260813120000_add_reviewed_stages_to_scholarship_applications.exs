defmodule Dbservice.Repo.Migrations.AddReviewedStagesToScholarshipApplications do
  use Ecto.Migration

  # Reviewer stage-tick persistence (af-scholarship, Poojita 2026-08-13): the
  # reviewer detail view ticks each application stage (About You / Education /
  # College & bank) as the reviewer opens it, and shortlisting / Docs Verified is
  # gated on all three having been reviewed. Until now that tick set lived only in
  # the browser session, so reopening an application after a resubmit round started
  # fresh. Persisting it per application lets the ticks survive across rounds.
  #
  # `{:array, :integer}` holds the reviewed stage numbers (1 / 2 / 3). Additive +
  # NOT NULL with a default '{}' → deploy-safe, no backfill needed.
  def change do
    alter table(:scholarship_applications) do
      add :reviewed_stages, {:array, :integer}, null: false, default: []
    end
  end
end
