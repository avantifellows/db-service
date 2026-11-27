defmodule Dbservice.Repo.Migrations.ScholarshipPhase4Foundations do
  use Ecto.Migration

  # Phase 4 foundations — slice 1 of the plan agreed with Sanghamitra on
  # 21-22 Oct 2026. Schema only: no screen reads any of this yet, and nothing
  # here changes how Phases 1-3 behave.
  #
  # Phase 4 is everything after the first payment: a student uploads a scorecard
  # each term and her bills, Accounts verifies the bills line by line, she asks
  # for a top-up, and Alekhya sends her through the SAME approval chain Phase 3
  # already runs (L1 Alekhya -> L2 Ram -> L3 Agny -> Accounts).
  #
  # Two things in the current build make that impossible, and both are fixed
  # here.
  #
  # ## 1. A paid student can never join a second lot
  #
  # `scholarship_lot_members_one_open_lot_per_student` is
  # `unique(application_id) WHERE removed_at IS NULL`. A paid membership is
  # never removed, so it holds that slot forever and the student can never be
  # put in another lot. Every top-up would fail at the first student.
  #
  # That index is doing TWO jobs at once, which is why it cannot simply be
  # dropped:
  #
  #   a. one open lot per student — the "no open lot" eligibility rule, enforced
  #      in the database rather than trusted to a query; and
  #   b. nobody is ever paid twice.
  #
  # Phase 4 needs (a) kept exactly as it is and (b) narrowed: a student may be
  # paid many times over the years, but her INITIAL disbursement must still
  # happen once and once only. So the one index becomes two, each doing one job:
  #
  #   * `..._one_open_lot_per_student` — unique on application_id among rows
  #     that are neither removed NOR yet paid. Identical to today's behaviour
  #     for an unpaid membership; it simply stops applying once she is paid.
  #   * `..._one_initial_payment_per_student` — unique on application_id among
  #     PAID, un-removed rows of an `initial` lot. A second initial payment is
  #     rejected by the database, which is the half of the old guarantee that
  #     actually mattered.
  #
  # `confirmed_at` is the payment marker throughout (set with `paid_on` by
  # Accounts' Confirm Disbursement), so the two indexes partition on it and
  # cannot both apply to the same row.
  #
  # `kind` is denormalised onto the member because a partial index cannot reach
  # through to its lot. It is written once, from the lot it belongs to, and a
  # lot's kind never changes after it is created.
  #
  # ## 2. Documents are one-per-type and overwrite
  #
  # `scholarship_documents` is keyed `(application_id, doc_type)` and a
  # re-upload deletes the previous rows and their S3 objects. Phase 4 needs many
  # per student and must keep every one: a scorecard each term, a bill for every
  # expense, several photos. So Phase 4's uploads do NOT go in that table. They
  # get their own rows here, and nothing is ever overwritten.
  #
  # The Phase 1-3 tables are untouched, so an application's own documents keep
  # behaving exactly as they do today.
  def up do
    # --- Cohorts -------------------------------------------------------------
    #
    # A cohort is the batch of students selected in one year (Sanghamitra,
    # 21 Oct). Seven exist. Cohort 7 is the 2026-27 intake — the only one this
    # portal has ever held. Cohorts 1-6 were selected in earlier years and have
    # no rows here at all; they arrive later through the CSV import (slice 3).
    #
    # Cohorts 4-7 are active: those students log in and use Phase 4. Cohorts 1-3
    # are historical — visible in the Reviewer and Finance dashboards, never
    # logging in. `is_active` is that distinction, not a toggle for switching
    # cohorts off.
    #
    # This is reference data, so it is seeded HERE rather than in a seeder:
    # seeders do not run on deploy.
    create table(:scholarship_cohorts) do
      add :number, :integer, null: false
      add :name, :string, null: false
      add :academic_year, :string
      # The programme's money for this cohort, in whole rupees, for the Finance
      # Dashboard. Nullable: the team has not given us figures for the older
      # cohorts, and a 0 would read as a real budget of nothing.
      add :budget_amount, :bigint
      add :is_active, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index(:scholarship_cohorts, [:number])

    execute """
            INSERT INTO scholarship_cohorts
              (number, name, academic_year, is_active, inserted_at, updated_at)
            VALUES
              (1, 'Cohort 1', NULL, false, NOW(), NOW()),
              (2, 'Cohort 2', NULL, false, NOW(), NOW()),
              (3, 'Cohort 3', NULL, false, NOW(), NOW()),
              (4, 'Cohort 4', NULL, true,  NOW(), NOW()),
              (5, 'Cohort 5', NULL, true,  NOW(), NOW()),
              (6, 'Cohort 6', NULL, true,  NOW(), NOW()),
              (7, 'Cohort 7', '2026-27', true, NOW(), NOW())
            """,
            "DELETE FROM scholarship_cohorts WHERE number BETWEEN 1 AND 7"

    # Every application this portal holds belongs to the 2026-27 intake, so they
    # are all Cohort 7. Nullable rather than defaulted: an application that
    # somehow has no cohort should read as unknown, not silently as Cohort 7.
    alter table(:scholarship_applications) do
      add :cohort_id, references(:scholarship_cohorts, on_delete: :restrict)
    end

    create index(:scholarship_applications, [:cohort_id])

    execute """
            UPDATE scholarship_applications
               SET cohort_id = (SELECT id FROM scholarship_cohorts WHERE number = 7)
            """,
            "UPDATE scholarship_applications SET cohort_id = NULL"

    # --- Lots: initial vs top-up --------------------------------------------
    #
    # Every lot that exists today is an initial disbursement, which is why the
    # default backfills correctly and why it is safe to make it NOT NULL.
    alter table(:scholarship_disbursement_lots) do
      add :kind, :string, null: false, default: "initial"
    end

    alter table(:scholarship_disbursement_lot_members) do
      add :kind, :string, null: false, default: "initial"
    end

    create index(:scholarship_disbursement_lots, [:cycle_id, :kind])

    # The index swap described at the top. Dropped and recreated under the same
    # name so the old guarantee is visibly replaced rather than quietly left
    # behind under a second name.
    drop index(:scholarship_disbursement_lot_members, [:application_id],
           name: :scholarship_lot_members_one_open_lot_per_student
         )

    create unique_index(
             :scholarship_disbursement_lot_members,
             [:application_id],
             where: "removed_at IS NULL AND confirmed_at IS NULL",
             name: :scholarship_lot_members_one_open_lot_per_student
           )

    create unique_index(
             :scholarship_disbursement_lot_members,
             [:application_id],
             where: "removed_at IS NULL AND confirmed_at IS NOT NULL AND kind = 'initial'",
             name: :scholarship_lot_members_one_initial_payment_per_student
           )

    # --- Scorecards ----------------------------------------------------------
    #
    # One row per UPLOAD, not per term: a second upload for the same term stacks
    # as another attempt and the latest one counts for top-up eligibility
    # (Sanghamitra, 22 Oct, option B). Nothing is replaced, so when Alekhya puts
    # a scorecard On Hold and the student sends a corrected copy, the version
    # Alekhya's note was written against is still there to read.
    #
    # Engineering is examined by semester, Medical by year, so `term_type` says
    # which `term_number` means.
    create table(:scholarship_scorecards) do
      add :application_id, references(:scholarship_applications, on_delete: :delete_all),
        null: false

      add :academic_year, :string, null: false
      add :term_type, :string, null: false
      add :term_number, :integer
      # 'pass' | 'fail' — a fail carries the backlog count she is asked for.
      add :result, :string, null: false
      add :backlog_count, :integer
      # Kept as given rather than as a percentage: a CGPA out of 10 and marks
      # out of 500 are both scores, and deriving a percentage on display is this
      # codebase's rule for anything computed.
      add :score, :decimal
      add :max_score, :decimal
      # 'pending' | 'verified' | 'on_hold' — Alekhya's verdict.
      add :status, :string, null: false, default: "pending"
      add :review_note, :text
      add :reviewed_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime
      # Staff-only academic label (PRD §3). Never shown to the student.
      add :staff_label, :string

      timestamps()
    end

    create index(:scholarship_scorecards, [:application_id])
    create index(:scholarship_scorecards, [:application_id, :academic_year, :term_number])
    create index(:scholarship_scorecards, [:status])

    # --- Bills ---------------------------------------------------------------
    #
    # A bill is one document carrying one or more expense lines, and ACCOUNTS
    # verifies it, not Alekhya (PRD §4; Sanghamitra corrected me on this,
    # 22 Oct). The verdict is per line: Approve, Partially Approve or Reject,
    # with a reason required for the last two.
    #
    # `reject_kind` is the choice Accounts makes when rejecting (Sanghamitra,
    # 22 Oct, option B):
    #
    #   * 'fix'        — bad scan, wrong page. She re-uploads against THIS bill;
    #                    the attempt stacks in scholarship_attachments.
    #   * 'ineligible' — this expense does not count. The bill is closed for
    #                    good and a valid expense goes in as a NEW bill with its
    #                    own amount, which is the whole reason the two are
    #                    distinguished.
    create table(:scholarship_bills) do
      add :application_id, references(:scholarship_applications, on_delete: :delete_all),
        null: false

      add :vendor, :string
      add :bill_date, :date
      add :bill_number, :string
      # 'pending' | 'approved' | 'partially_approved' | 'rejected', derived from
      # its lines when they are all actioned.
      add :status, :string, null: false, default: "pending"
      add :reject_kind, :string
      add :reject_reason, :text
      add :actioned_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :actioned_at, :utc_datetime

      timestamps()
    end

    create index(:scholarship_bills, [:application_id])
    create index(:scholarship_bills, [:application_id, :status])

    # Amounts are whole rupees in an integer, as scholarship_disbursement_lot_members.amount
    # already is — the money in this product has never had paise.
    #
    # `approved_amount` is what Accounts allowed, which is the ONLY thing that
    # counts toward Amount Utilised (PRD §6). It is NULL until actioned, equals
    # claimed_amount on a full approval, is lower on a partial one, and is 0 on
    # a rejection.
    create table(:scholarship_bill_lines) do
      add :bill_id, references(:scholarship_bills, on_delete: :delete_all), null: false
      add :category, :string, null: false
      add :description, :string
      add :claimed_amount, :integer, null: false
      add :approved_amount, :integer
      # 'pending' | 'approved' | 'partially_approved' | 'rejected'
      add :status, :string, null: false, default: "pending"
      add :reason, :text
      add :actioned_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :actioned_at, :utc_datetime

      timestamps()
    end

    create index(:scholarship_bill_lines, [:bill_id])
    create index(:scholarship_bill_lines, [:status])

    # --- Student uploads -----------------------------------------------------
    #
    # The remaining Phase 4 uploads that are neither a scorecard nor a bill:
    # required forms, internship and placement proof, photographs (PRD §2).
    # They share one table because they share one behaviour — she uploads, it is
    # kept, nothing is verified and nothing is overwritten.
    create table(:scholarship_student_uploads) do
      add :application_id, references(:scholarship_applications, on_delete: :delete_all),
        null: false

      # 'form' | 'internship' | 'placement' | 'photo'
      add :kind, :string, null: false
      add :title, :string
      add :notes, :text

      timestamps()
    end

    create index(:scholarship_student_uploads, [:application_id])
    create index(:scholarship_student_uploads, [:application_id, :kind])

    # --- Attachments ---------------------------------------------------------
    #
    # The files behind all three of the above. One row per PAGE, the same shape
    # scholarship_documents uses, so a multi-page PDF or a set of photographs
    # works the way it already does elsewhere.
    #
    # `owner_type` + `owner_id` rather than three near-identical tables: the
    # file columns and the S3 handling are identical for all three, and the
    # alternative is the same five columns written out three times. There is no
    # foreign key on `owner_id` — that is the cost of the shape, and it is paid
    # deliberately: the parents all cascade from the application, so an orphan
    # can only appear if a parent is deleted directly, which nothing does.
    #
    # `attempt` is what makes a re-upload stack instead of replace: a corrected
    # scorecard or a re-scanned bill arrives as attempt 2 beside attempt 1,
    # never on top of it. Reads take MAX(attempt) and ignore the rest.
    create table(:scholarship_attachments) do
      # 'scorecard' | 'bill' | 'student_upload'
      add :owner_type, :string, null: false
      add :owner_id, :bigint, null: false
      add :attempt, :integer, null: false, default: 1
      add :document_uuid, :string, null: false
      add :s3_key, :string, null: false
      add :mime_type, :string, null: false
      add :byte_size, :integer, null: false
      add :page_number, :integer, null: false, default: 1
      add :uploaded_by_staff, :boolean, null: false, default: false

      timestamps()
    end

    create index(:scholarship_attachments, [:owner_type, :owner_id])

    create unique_index(
             :scholarship_attachments,
             [:owner_type, :owner_id, :attempt, :page_number],
             name: :scholarship_attachments_one_row_per_page
           )
  end

  def down do
    drop table(:scholarship_attachments)
    drop table(:scholarship_student_uploads)
    drop table(:scholarship_bill_lines)
    drop table(:scholarship_bills)
    drop table(:scholarship_scorecards)

    drop index(:scholarship_disbursement_lot_members, [:application_id],
           name: :scholarship_lot_members_one_initial_payment_per_student
         )

    drop index(:scholarship_disbursement_lot_members, [:application_id],
           name: :scholarship_lot_members_one_open_lot_per_student
         )

    # Back to the Phase 3 guarantee exactly as it was.
    create unique_index(
             :scholarship_disbursement_lot_members,
             [:application_id],
             where: "removed_at IS NULL",
             name: :scholarship_lot_members_one_open_lot_per_student
           )

    drop index(:scholarship_disbursement_lots, [:cycle_id, :kind])

    alter table(:scholarship_disbursement_lot_members) do
      remove :kind
    end

    alter table(:scholarship_disbursement_lots) do
      remove :kind
    end

    drop index(:scholarship_applications, [:cohort_id])

    alter table(:scholarship_applications) do
      remove :cohort_id
    end

    drop table(:scholarship_cohorts)
  end
end
