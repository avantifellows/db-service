defmodule Dbservice.Repo.Migrations.ScholarshipPhase4ConversationsAndRequests do
  use Ecto.Migration

  # Phase 4 slices 4 to 7 — the four things the first foundations migration
  # (20261022150000) left out, because they are about people talking to each
  # other rather than about the documents themselves.
  #
  # Schema only. Nothing reads any of this yet.
  def change do
    # --- The On-Hold conversation (slice 4) ---------------------------------
    #
    # Alekhya puts a scorecard On Hold with a reason, and the student answers —
    # by writing back, by uploading a corrected copy, or both (PRD §2). The
    # reason itself lives on the scorecard as `review_note`, because a scorecard
    # has exactly one current verdict; everything said AFTER that verdict is a
    # thread, and a thread needs rows.
    #
    # Not the existing `scholarship_review_flags`: a flag hangs off an
    # application and a document BLOCK, and these hang off one scorecard among
    # several, each with its own status. Bending the flag table into that shape
    # would make every existing flag query say "and not this kind".
    create table(:scholarship_scorecard_messages) do
      add :scorecard_id, references(:scholarship_scorecards, on_delete: :delete_all),
        null: false

      # 'student' | 'reviewer' — who is speaking, which is what the card shows
      # on each side of the thread.
      add :author_role, :string, null: false
      # The staff row, where staff said it. Null for the student: she is
      # identified by the scorecard she is writing under.
      add :author_id, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :body, :text, null: false

      timestamps()
    end

    create index(:scholarship_scorecard_messages, [:scorecard_id])

    # --- Asking for a scorecard that has not arrived (slice 4) --------------
    #
    # A reminder is about a scorecard that does NOT exist, so it cannot hang off
    # one. It hangs off the student, and records the term she was asked about,
    # so "we have already chased her twice this semester" is answerable and the
    # Reviewer screen can stop her being chased a third time in a morning.
    create table(:scholarship_scorecard_reminders) do
      add :application_id, references(:scholarship_applications, on_delete: :delete_all),
        null: false

      add :academic_year, :string
      add :term_number, :integer
      add :sent_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :sent_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:scholarship_scorecard_reminders, [:application_id])

    # --- Request Payment (slice 6) ------------------------------------------
    #
    # Locked with Sanghamitra on 22 Oct, option A: ONE standing request. It
    # opens when the student asks, and closes only when she is paid or when
    # Alekhya dismisses it with a note. It survives Agny rejecting the lot she
    # was in — she never knew a lot existed. She cannot raise a second one while
    # the first is open, which is what the partial unique index below enforces
    # in the database rather than trusting a query to check.
    #
    # Alekhya's list is therefore a queue: who is waiting, and since when,
    # oldest first.
    create table(:scholarship_payment_requests) do
      add :application_id, references(:scholarship_applications, on_delete: :delete_all),
        null: false

      add :requested_at, :utc_datetime, null: false
      # Set when the money is paid — the request's happy ending.
      add :fulfilled_at, :utc_datetime
      # Set when Alekhya closes it instead. The note is mandatory in the app:
      # it is the only record of why someone who asked was told no.
      add :dismissed_at, :utc_datetime
      add :dismissed_by, references(:scholarship_reviewers, on_delete: :nilify_all)
      add :dismissal_note, :text

      timestamps()
    end

    create index(:scholarship_payment_requests, [:application_id])

    create unique_index(:scholarship_payment_requests, [:application_id],
             where: "fulfilled_at IS NULL AND dismissed_at IS NULL",
             name: :scholarship_payment_requests_one_open_per_student
           )

    # --- Alekhya's manual exception (slice 7) -------------------------------
    #
    # She may put a Not Eligible student in a top-up lot anyway — an unverified
    # scorecard, under 80% utilisation, bills still being checked (PRD §3). The
    # PRD's own condition is that the reason stays VISIBLE, so it is recorded on
    # the membership rather than inferred later from a student who has since
    # become eligible.
    alter table(:scholarship_disbursement_lot_members) do
      add :added_despite_reason, :string
      add :added_despite_note, :text
    end
  end
end
