defmodule Dbservice.Repo.Migrations.AddRespondedAtToScholarshipReviewFlags do
  use Ecto.Migration

  # Reviewer flag-lifecycle redesign (af-scholarship): a flag now moves through
  # three states — Open → Responded → Resolved — instead of open/resolved.
  # `responded_at` marks the new middle state, stamped when the applicant
  # resubmits after the flag was raised (this replaces the old behaviour where a
  # resubmit auto-set `resolved_at`). `resolved_at` becomes an explicit reviewer
  # action. State derives from the two timestamps: resolved_at → Resolved; else
  # responded_at → Responded; else Open. Additive + nullable → deploy-safe, no
  # backfill needed.
  def change do
    alter table(:scholarship_review_flags) do
      add :responded_at, :utc_datetime
    end
  end
end
