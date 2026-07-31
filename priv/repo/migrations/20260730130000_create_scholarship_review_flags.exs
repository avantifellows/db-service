defmodule Dbservice.Repo.Migrations.CreateScholarshipReviewFlags do
  use Ecto.Migration

  # Reviewer Portal Phase 1 (af-scholarship ADR 0004): reviewers flag individual
  # DOCUMENT BLOCKS of a submitted application for the applicant to fix. One row
  # per flagged block per review round. A flag is raised in the reviewer's local
  # session and persisted here when they "Send Flags"; `resolved_at` is stamped
  # when the applicant resubmits that block. Status transitions still live in
  # scholarship_status_events — this table is only the per-block flag detail.
  def change do
    create table(:scholarship_review_flags) do
      add :application_id,
          references(:scholarship_applications, on_delete: :delete_all),
          null: false

      # One of the nine document blocks: category, income, photo, class10,
      # class12, entrance_scorecard, seat_allotment, fee_structure, bank_passbook.
      add :document_block, :string, null: false
      # The reviewer's note to the applicant (≤500 chars, enforced app-side).
      add :comment, :text, null: false
      # The review round this flag belongs to (1 = first pass, 2 = after a
      # resubmission, …) so re-review rounds stay distinguishable.
      add :round, :integer, null: false, default: 1
      # Set when the applicant resubmits this block; null while still open.
      add :resolved_at, :utc_datetime

      # Who raised the flag. Nilified (not deleted) if the reviewer row goes away,
      # so the flag history survives.
      add :reviewer_id,
          references(:scholarship_reviewers, on_delete: :nilify_all)

      timestamps()
    end

    create index(:scholarship_review_flags, [:application_id])
    create index(:scholarship_review_flags, [:application_id, :round])
    # A reviewer raises at most one flag per block per round.
    create unique_index(
             :scholarship_review_flags,
             [:application_id, :document_block, :round]
           )
  end
end
