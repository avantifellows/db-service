defmodule Dbservice.Repo.Migrations.ScholarshipPhase4CohortImport do
  use Ecto.Migration

  # Phase 4 slice 3 — where an imported scholar came from.
  #
  # Cohorts 1-6 were selected in earlier years and have never existed in this
  # portal: no application, no college, no payment history (plan v2 §3.1,
  # settled with Alekhya on 21 Oct 2026). They arrive by CSV import, and each
  # one becomes an ordinary `scholarship_applications` row — because documents,
  # lots, payments, the student portal and bank verification ALL key on the
  # application, and representing a scholar any other way would mean building a
  # parallel path for every one of them.
  #
  # Which means the rows that decide who gets paid will shortly include rows
  # nobody applied for. These two columns are how anyone looking at one can
  # tell: when it was imported, and by whom. Null is the ordinary case — a
  # student who applied through the portal herself.
  #
  # The re-import key is NOT added here. A corrected sheet is matched on
  # `student_id`, the scholarship Student ID the team already holds for every
  # one of cohorts 1-6 (confirmed 21-22 Oct), and that column exists and is
  # uniquely indexed already. A second identifier would be a second answer to
  # "which scholar is this row", and the import is the one place that can least
  # afford two.
  def change do
    alter table(:scholarship_applications) do
      add :imported_at, :utc_datetime
      add :imported_by, references(:scholarship_reviewers, on_delete: :nilify_all)
    end

    # The same question about a bill.
    #
    # An imported scholar arrives with a figure for how much of her money is
    # already accounted for (confirmed 21-22 Oct: the team holds it, and
    # without it she would read as 0% utilised and be blocked from a top-up
    # she is entitled to). That figure is recorded as an approved bill rather
    # than as a column of its own, so that "Amount Utilised = what Accounts
    # approved" stays the ONE definition of utilisation, with nothing added to
    # it afterwards. This column is how that bill says what it is, on her Bills
    # page and to the next re-import, which updates it rather than adding a
    # second one.
    alter table(:scholarship_bills) do
      add :imported_at, :utc_datetime
    end

    # Small and highly selective: every imported row, none of the portal's own.
    # The Finance Dashboard reads "the imported cohorts" as a set, and the
    # Application Review queue has to be able to say "not these".
    create index(:scholarship_applications, [:imported_at],
             where: "imported_at IS NOT NULL",
             name: :scholarship_applications_imported_index
           )
  end
end
