defmodule Dbservice.Repo.Migrations.ScholarshipPhase4Round2 do
  use Ecto.Migration

  # Phase 4, second round — the schema behind Sanghamitra and Alekhya's
  # 29 Oct 2026 testing list. Three unrelated things, in one migration because
  # they ship in one deployment and splitting them would only mean three
  # chances to apply two.
  #
  # ⚠️ ORDERING. This migration ALTERS tables created by the five Phase 4
  # migrations (#810, #812, #813, #814, #815), none of which were on `main`
  # when this was written — they were applied to staging by hand. Those five
  # must be merged and applied BEFORE this one, or
  # `scholarship_scorecards` does not exist and this fails on the first alter.
  # The version numbers already order it last; the risk is only in merging
  # this one on its own.
  def change do
    # --- 1. A reviewer comment the student reads (item 7) --------------------
    #
    # Alekhya already has two ways to write about a scorecard, and neither is
    # this one. `review_note` is the On Hold reason: it exists to say what is
    # WRONG, it is required when she holds a scorecard, and it reads as a
    # refusal. `scholarship_scorecard_messages` is the back-and-forth that
    # follows, append-only, where a correction is discussed.
    #
    # What was missing is a plain remark attached to the scorecard itself --
    # on a VERIFIED one as much as a held one -- that the student can see.
    # A column rather than a message because it is a field she edits and
    # re-edits, not a thing she said at a moment in time; the thread would turn
    # every correction of a typo into a second entry in a conversation.
    #
    # It sits beside `staff_label`, which is its exact opposite and the reason
    # the two are easy to confuse: the label is internal and never leaves the
    # reviewer screens, this is written to be read by the person it is about.
    alter table(:scholarship_scorecards) do
      add :reviewer_comment, :text
    end

    # --- 2. The financial year a scholar's funding belongs to (items 13, 15) -
    #
    # "2025-2026", both years in full -- the format the team writes and the one
    # asked for in the import sheet. Deliberately NOT the "2025-26" shape used
    # for an academic year on `scholarship_cohorts` and on a scorecard: they are
    # different years that only sometimes coincide, and a reader who cannot tell
    # them apart at a glance is a reader who will eventually filter by the wrong
    # one.
    #
    # NOT what the Finance Dashboard filters on. A year there is the year the
    # money MOVED in, read off the payment's own date (Sanghamitra, 29 Oct,
    # option B) -- a scholar funded across two years belongs to both, which one
    # year on her row could never say.
    #
    # This column is what gives money a year when the date cannot: an imported
    # lump the team recorded with no day against it has nothing else to go on,
    # and the dashboard's year query COALESCEs down to it. A typed column
    # rather than another key in `stage3_data` because that query reads it per
    # payment (this codebase promotes a field out of the blob exactly when it
    # is queried on, and not before), and the import writes and re-writes it.
    #
    # Nullable, and backfilled below only where the answer is already known.
    alter table(:scholarship_applications) do
      add :financial_year, :string
    end

    create index(:scholarship_applications, [:financial_year])

    # Cohort 7 is the 2026-27 intake, the only one this portal has ever held,
    # and it never comes through the CSV, so nothing else would ever fill it.
    # Its payments are recorded in the portal with the day they were paid, so
    # the dashboard rarely has to fall back this far -- but an undated rupee of
    # theirs can then only be 2026-2027, and this is where that is written down.
    # Cohorts 1-6 arrive with the column filled from their sheet.
    execute """
            UPDATE scholarship_applications a
               SET financial_year = '2026-2027'
              FROM scholarship_cohorts c
             WHERE c.id = a.cohort_id
               AND c.number = 7
               AND a.financial_year IS NULL
            """,
            """
            UPDATE scholarship_applications SET financial_year = NULL
            """

    # --- 3. A record of every cohort CSV upload (item 15) --------------------
    #
    # The import already refuses a bad sheet row by row and shows the reasons
    # on screen. What it has never done is remember: close the tab and there is
    # no answer to "did that file go through, and what was wrong with it".
    # Alekhya asked for the upload history, the status of each one, and the
    # errors of a failed one openable afterwards.
    #
    # `status` is 'in_process' | 'successful' | 'failed'. It is written rather
    # than derived because the interesting case is the one with no outcome at
    # all -- a run that died midway leaves its row saying 'in_process', which is
    # exactly the honest answer and the one a derived status could never give.
    #
    # The errors are stored as jsonb, as the same {row, column, message} shape
    # the screen already renders. They are a report ABOUT a file rather than
    # data of our own: nothing joins to them, nothing queries inside them, and
    # the only thing anyone does is read the list back.
    create table(:scholarship_cohort_imports) do
      add :uploaded_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :filename, :string
      add :status, :string, null: false, default: "in_process"
      add :row_count, :integer, null: false, default: 0
      add :created_count, :integer, null: false, default: 0
      add :updated_count, :integer, null: false, default: 0
      add :invalid_count, :integer, null: false, default: 0
      add :errors, :jsonb, null: false, default: fragment("'[]'::jsonb")
      # Why the run as a whole failed, where it was not the rows' fault.
      add :failure_reason, :text
      add :finished_at, :utc_datetime

      timestamps()
    end

    # The screen reads this newest-first and never by anything else.
    create index(:scholarship_cohort_imports, [:inserted_at])
  end
end
