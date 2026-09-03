defmodule Dbservice.Repo.Migrations.ScholarshipPhase2BankVerification do
  use Ecto.Migration

  # af-scholarship Phase 2 (bank verification + penny drop, new "accounts" role).
  #
  # 1. scholarship_review_flags becomes the single flag table for every flag kind
  #    (decision Q3, 3 Sep 2026): `kind` says what the flag is about and
  #    `raised_by_role` who raised it. Existing rows are Phase-1 reviewer flags on
  #    application document blocks, so both defaults backfill them correctly.
  #      kind:           application_block | bank_details | penny_drop | disbursement
  #      raised_by_role: reviewer | accounts | student
  #    Only `application_block` flags move the application lifecycle status; the
  #    others (post-shortlist) never do. The unique key gains `kind` so an Accounts
  #    bank flag and a Phase-1 reviewer flag on the same block/round can coexist.
  #
  # 2. scholarship_applications gains the Accounts-owned bank-verification and
  #    penny-drop facts. Bank status is DERIVED, never stored:
  #      bank_verified_at set            -> verified
  #      open bank_details flag          -> flagged
  #      responded bank_details flag     -> awaiting_review
  #      otherwise                       -> pending_review
  #    Penny-drop status likewise derives from sent_at / confirmed_at / an open
  #    student-raised penny_drop flag (failed_investigate). All additive + nullable
  #    or defaulted -> deploy-safe, no backfill.
  #
  # 3. The "accounts" role needs no schema change: scholarship_reviewers.role is a
  #    plain string (reviewer | admin | accounts). Alekhya becomes admin (Q13).
  def change do
    alter table(:scholarship_review_flags) do
      add :kind, :string, null: false, default: "application_block"
      add :raised_by_role, :string, null: false, default: "reviewer"
    end

    drop unique_index(:scholarship_review_flags, [:application_id, :document_block, :round])

    create unique_index(
             :scholarship_review_flags,
             [:application_id, :kind, :document_block, :round]
           )

    create index(:scholarship_review_flags, [:application_id, :kind])

    alter table(:scholarship_applications) do
      add :bank_verified_at, :utc_datetime
      add :bank_verified_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :penny_drop_sent_at, :utc_datetime
      add :penny_drop_sent_count, :integer, null: false, default: 0
      add :penny_drop_confirmed_at, :utc_datetime
    end

    execute(
      "UPDATE scholarship_reviewers SET role = 'admin' WHERE LOWER(email) = 'alekhya@avantifellows.org'",
      "UPDATE scholarship_reviewers SET role = 'reviewer' WHERE LOWER(email) = 'alekhya@avantifellows.org'"
    )
  end
end
