defmodule Dbservice.Repo.Migrations.ScholarshipInitialDisbursement do
  use Ecto.Migration

  # af-scholarship Phase 3 — Initial Disbursement. The Program Team's five
  # points (1 Oct 2026, via Sanghamitra) plus the twelve-question grilling round
  # the same day. The app side is af-scholarship PR #198, and
  # `docs/adr/0006-initial-disbursement-chain.md` there carries every decision
  # with its reasoning.
  #
  # 1. scholarship_disbursement_lots — money moves in a NAMED LOT (Q1): Alekhya
  #    builds it, Ram edits amounts and may drop a student, Agny signs off the
  #    total, Accounts pays. The lot keeps its identity the whole way down, so
  #    `stage` moves and the row does not. The single backwards edge is Agny
  #    returning a lot to Alekhya (Q3), which keeps its number.
  #
  #    The lot NUMBER is not stored: it is the position in (cycle_id, id) order,
  #    the same way the interview session number is the position in date/time
  #    order (20260911080000). A stored counter would need its own uniqueness
  #    and could disagree with the ordering people see.
  #
  # 2. scholarship_disbursement_lot_members — one row per student in a lot,
  #    carrying her approved `amount` (whole rupees as an integer: a float would
  #    make the total Agny signs disagree with the sum of the rows he was shown)
  #    and, once Accounts pays, the confirmation.
  #
  #    `paid_on` / `confirmed_at` / `confirmed_by` are ONE confirmation, not a
  #    log. Q4 first gave Accounts a Cancel action with a note and a retry
  #    history; the Program Team removed it the same afternoon ("Accounts should
  #    only have the Confirm Disbursement option"), so there is no second
  #    attempt to record. The receipt is NOT a column — it rides in
  #    scholarship_documents like every other upload, keyed (application_id,
  #    doc_type = "disbursement_receipt").
  #
  #    The partial unique index on `application_id WHERE removed_at IS NULL`
  #    does two jobs at once: a student can be in only ONE open lot (without it
  #    Alekhya could put her in Lot #3 and Lot #4 the same morning and both
  #    would pay her), and because a paid student never returns to the pool
  #    (Q7, once only), it also makes paying anyone twice impossible in the
  #    database rather than only in app code.
  #
  # 3. scholarship_disbursement_lot_events — every stage move, mirroring how
  #    scholarship_status_events records an application's status changes. This
  #    is where the mandatory notes live: Ram's reason for dropping a student
  #    (Q2) and Agny's reason for returning a lot (Q3). It is the only record of
  #    why someone payable was passed over.
  #
  # 4. Three staff rows. alekhya@, ram@ and agny@ have no portal login at all
  #    today. No new portal or sign-in button is needed (Q11): Alekhya and Ram
  #    work inside the Reviewer portal, Agny inside the Accounts portal, and the
  #    three approval levels are ROLES. `scholarship_reviewers.role` is a plain
  #    varchar with no check constraint, so the new values need no DDL.
  #
  #    ⚠️ DEPLOY ORDER. The app denies a sign-in outright when it meets a role
  #    string it does not know (`parseStaffRoles` returns null by design, so a
  #    typo in a manual INSERT cannot quietly grant access). Deploy
  #    af-scholarship #198 BEFORE this migration reaches an environment, or
  #    these three cannot sign in. They cannot sign in today either, so there is
  #    no regression — but the order still matters for anyone whose role is
  #    later edited.
  #
  #    Each row carries TWO roles: the portal's ordinary role and the level.
  #    Alekhya and Ram keep the reviewer's own work — the application queue,
  #    bank verification, the interview round — and Agny keeps the Accounts
  #    queue, each with their approval on top (Sanghamitra, 3 Oct 2026, settling
  #    the question left open on 1 Oct; the disbursement-only default shipped in
  #    af-scholarship #200 is reversed here). The roles compose, so this is a
  #    row value and needed no app change. Dropping someone back to
  #    disbursement-only is the reverse UPDATE, equally not a migration.
  #
  # All additive -> deploy-safe, no backfill. Apply on prod BEFORE the app
  # deploy (the responded_at lesson, 7 Aug 2026).
  def up do
    create table(:scholarship_disbursement_lots) do
      add :cycle_id, references(:scholarship_cycles, on_delete: :delete_all), null: false

      # with_alekhya | with_ram | with_agny | with_accounts
      add :stage, :string, null: false, default: "with_alekhya"
      add :created_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      # Set when every student in the lot has been paid.
      add :closed_at, :utc_datetime

      timestamps()
    end

    create index(:scholarship_disbursement_lots, [:cycle_id, :stage])

    create table(:scholarship_disbursement_lot_members) do
      add :lot_id, references(:scholarship_disbursement_lots, on_delete: :delete_all), null: false

      add :application_id, references(:scholarship_applications, on_delete: :restrict),
        null: false

      # Whole rupees. No paise: every figure in this programme is a round
      # scholarship instalment.
      add :amount, :integer, null: false

      # Dropped by Alekhya while the lot was hers (no note needed — an
      # unapproved draft) or by Ram, whose removal_note is required (Q2).
      add :removed_at, :utc_datetime
      add :removed_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :removal_note, :text

      # Confirm Disbursement — the one action Accounts has.
      add :paid_on, :date
      add :confirmed_at, :utc_datetime
      add :confirmed_by, references(:scholarship_reviewers, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:scholarship_disbursement_lot_members, [:lot_id, :application_id])
    create index(:scholarship_disbursement_lot_members, [:lot_id])

    create unique_index(
             :scholarship_disbursement_lot_members,
             [:application_id],
             where: "removed_at IS NULL",
             name: :scholarship_lot_members_one_open_lot_per_student
           )

    create table(:scholarship_disbursement_lot_events) do
      add :lot_id, references(:scholarship_disbursement_lots, on_delete: :delete_all), null: false

      add :from_stage, :string
      add :to_stage, :string, null: false
      # approved | returned | removed_student | closed
      add :action, :string, null: false
      add :actor_id, references(:scholarship_reviewers, on_delete: :nilify_all)
      # Required for a return (Q3) and for a student removal (Q2).
      add :notes, :text

      timestamps(updated_at: false)
    end

    create index(:scholarship_disbursement_lot_events, [:lot_id])

    execute("""
    INSERT INTO scholarship_reviewers (email, name, role, is_active, inserted_at, updated_at)
    VALUES
      ('alekhya@avantifellows.org', 'Alekhya', 'reviewer,disbursement_l1', true, NOW(), NOW()),
      ('ram@avantifellows.org', 'Ram', 'reviewer,disbursement_l2', true, NOW(), NOW()),
      ('agny@avantifellows.org', 'Agny', 'accounts,disbursement_l3', true, NOW(), NOW())
    ON CONFLICT (email) DO NOTHING
    """)
  end

  def down do
    execute("""
    DELETE FROM scholarship_reviewers
    WHERE email IN (
      'alekhya@avantifellows.org',
      'ram@avantifellows.org',
      'agny@avantifellows.org'
    )
    AND role IN (
      'reviewer,disbursement_l1',
      'reviewer,disbursement_l2',
      'accounts,disbursement_l3'
    )
    """)

    drop table(:scholarship_disbursement_lot_events)
    drop table(:scholarship_disbursement_lot_members)
    drop table(:scholarship_disbursement_lots)
  end
end
